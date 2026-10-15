# Receitas de produção

Acesso: `ssh -o BatchMode=yes deploy@72.61.24.205`, depois
`docker exec central-postgres psql -U postgres -d central`.

**Nunca canalize para `head`, `grep -m` ou qualquer coisa que feche o pipe.** O `SIGPIPE` mata a
sessão, e se houver transação aberta ela fica órfã segurando lock até o backend perceber o socket
morto. Grave em arquivo e leia depois.

## Leitura segura

Toda sessão de leitura abre assim:

```sql
set default_transaction_read_only = on;
```

Exemplo completo, com o padrão de escape que funciona pelo SSH:

```bash
ssh -o BatchMode=yes deploy@72.61.24.205 'docker exec central-postgres psql -U postgres -d central -X -q -P pager=off \
 -c "set default_transaction_read_only=on;" \
 -c "select relname, n_live_tup from pg_stat_user_tables where schemaname='"'"'central'"'"' order by n_live_tup desc limit 10;"'
```

## Medição que escreve, com reversão

Só com autorização explícita, e **`rollback` obrigatório**. Confirme a reversão no mesmo bloco:

```bash
ssh -o BatchMode=yes deploy@72.61.24.205 'docker exec central-postgres psql -U postgres -d central -X -q -P pager=off -v ON_ERROR_STOP=1 \
 -c "begin;" \
 -c "set local lock_timeout = '"'"'3s'"'"';" \
 -c "set local statement_timeout = '"'"'30s'"'"';" \
 -c "set local idle_in_transaction_session_timeout = '"'"'60s'"'"';" \
 -c "set jit = off;" \
 -c "create index idx_teste on central.<tabela> (<colunas>);" \
 -c "explain (analyze, buffers) <query>;" \
 -c "rollback;" \
 -c "select count(*) from pg_indexes where indexname = '"'"'idx_teste'"'"';"'
```

A última linha tem que devolver `0`. Ao fim de uma bateria, **confirme a contagem total de índices
do schema** — qualquer divergência significa que uma transação escapou, e aí você para e investiga.

Os três timeouts não são decoração:

- `lock_timeout` limita quanto **você espera** por um lock.
- `statement_timeout` põe teto no statement.
- `idle_in_transaction_session_timeout` mata transação órfã que já detém lock. **É o que faltava
  quando o SIGPIPE derrubou uma sessão no meio de um `DROP INDEX`.**

## Diagnóstico de índice

```sql
-- duplicata exata
select array_agg(indexrelid::regclass::text), indrelid::regclass::text
from pg_index i join pg_class c on c.oid = i.indexrelid join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'central'
group by indrelid, indkey::text, coalesce(indexprs::text,''), coalesce(indpred::text,'')
having count(*) > 1;

-- indice invalido (resto de CONCURRENTLY que falhou)
select indexrelid::regclass from pg_index where not indisvalid or not indisready;

-- uso e tamanho
select relname, indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid))
from pg_stat_user_indexes where schemaname = 'central' order by idx_scan desc;

-- paginas e cache: e isto que diz se seq scan doi
select t.relname, c.relpages, t.n_live_tup, t.seq_scan, io.heap_blks_read, io.heap_blks_hit
from pg_stat_user_tables t
  join pg_class c on c.oid = t.relid
  join pg_statio_user_tables io on io.relid = t.relid
where t.schemaname = 'central' order by (t.seq_scan * c.relpages) desc;
```

**Quatro categorias de poda**, e a segunda mata quem tem pressa:

| Categoria | Tratamento |
|---|---|
| Duplicata exata (`indkey`, `indclass`, `indpred`, `indexprs` iguais) | `DROP` incondicional |
| Redundante por prefixo | `DROP` **só se** o mais longo não for parcial, o mais curto não for unique, e opclass, collation, direção e `NULLS FIRST/LAST` forem compatíveis |
| Parcial com predicado órfão | Reescrever sem o `WHERE` ou dropar. Decide o `EXPLAIN` |
| PK ou unique com `idx_scan = 0` | **Não se toca.** A verificação de unicidade não passa pelo contador |

E uma categoria de **criação** que costuma ser esquecida: FK sem índice de suporte. Mas só cria com
`EXPLAIN` provando necessidade.

## Como não se enganar

- **`EXPLAIN ANALYZE` executa.** Só em `SELECT`. Para `INSERT ... ON CONFLICT`, use `EXPLAIN` puro:
  a inferência de árbitro acontece em tempo de planejamento e já mostra
  `Conflict Arbiter Indexes`, sem inserir nada.
- **Rode duas vezes, use a segunda.** A base vive em cache; a primeira paga leitura fria.
- **Isole o JIT.** Custo estimado acima de 100.000 dispara compilação que pode ser 90% do tempo.
  `SET jit = off` antes de comparar antes e depois.
- **`idx_scan` não identifica a query.** Serve para saber que algo usa, não o quê. Redundância se
  prova pelo catálogo.
- **`stats_reset` é NULL aqui**: contadores acumulam desde a criação do banco, mas estão vivos.

## Ferramentas ausentes

`pg_stat_statements` e `pg_trgm` estão **disponíveis mas não instalados**. `pg_stat_statements` exige
`shared_preload_libraries` e **restart do Postgres** — não peça de graça. `pg_trgm` é `trusted` no 17
e entra por migration sem restart.

Para ranquear query quente sem `pg_stat_statements`: cruze `pg_stat_user_tables` (que **é** contador
de frequência por tabela) com o mapa rota → query → tabela lido do código, mais os intervalos de poll
do front. Amostrar `pg_stat_activity` **não funciona nesta base**: ela faz ~0,33 query/s e fica
ocupada ~0,02% do tempo, então 12.000 amostras devolvem zero linhas.
