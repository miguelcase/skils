#!/usr/bin/env python3
"""Copy bundled skills and adapt their entry points for Codex (stdlib only)."""
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile


def install(source: Path, destination: Path) -> int:
    destination.mkdir(parents=True, exist_ok=True)
    installed = kept = failures = 0
    for folder in sorted(source.iterdir()):
        entry = folder / 'SKILL.md'
        if not entry.is_file():
            continue
        target = destination / folder.name
        if target.exists() or target.is_symlink():
            kept += 1
            print(f'  ja existe, mantida: {folder.name}')
            continue
        try:
            text = entry.read_text(encoding='utf-8')
            parts = text.split('---', 2)
            if len(parts) != 3 or parts[0].strip():
                raise ValueError('SKILL.md sem frontmatter')
            description = re.search(r'^description: (.+)$', parts[1], re.MULTILINE)
            if not description:
                raise ValueError('description ausente ou formato nao suportado')
            description = description.group(1).strip()
            # The bundled descriptions are plain single-line YAML scalars.
            if description.startswith(('"', "'", '|', '>')):
                raise ValueError('description precisa ser um escalar simples em uma linha')
            name = folder.name
            if not re.fullmatch(r'[a-z0-9-]{1,64}', name):
                raise ValueError('nome de pasta invalido para skill')
            header = f'---\nname: {name}\ndescription: {json.dumps(description, ensure_ascii=False)}\n---\n'
            note = (
                '\n## Compatibilidade com Codex\n\n'
                f'Esta copia foi preparada para Codex. Invoque com `${name}` ou pelo seletor de skills. '
                'As instrucoes abaixo vieram de uma skill para Claude Code: interprete mencoes a Claude '
                'como o agente atual e comandos /skill como mencoes $skill. Use as ferramentas equivalentes '
                'disponiveis no Codex; nomes como Bash, Read, Task e ferramentas de plugins nao sao APIs '
                'garantidas neste ambiente. Resolva scripts, referencias e assets a partir da pasta deste '
                'SKILL.md, sem depender de caminhos ~/.claude. Se uma etapa exigir ferramenta, plugin, '
                'MCP ou recurso ausente, informe o requisito e nao simule sua execucao. '
                'As permissoes e instrucoes do ambiente atual continuam valendo.\n'
            )
            # Stage the complete copy before publishing it into the discovery directory.
            with tempfile.TemporaryDirectory(prefix='.codex-skill-', dir=destination.parent) as staging:
                staged = Path(staging) / name
                shutil.copytree(folder, staged)
                (staged / 'SKILL.md').write_text(header + note + parts[2], encoding='utf-8')
                if target.exists() or target.is_symlink():
                    raise FileExistsError(f'destino apareceu durante a copia: {target}')
                staged.rename(target)
            installed += 1
        except (OSError, ValueError) as error:
            failures += 1
            print(f'  FALHOU: {folder.name}: {error}', file=sys.stderr)
    print(f'  {installed} instaladas, {kept} mantidas, {failures} falhas')
    print(f'  Playwright: cd "{destination / "playwright-skill"}" && npm run setup')
    return 1 if failures else 0


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Uso: install_codex_skills.py ORIGEM DESTINO')
    raise SystemExit(install(Path(sys.argv[1]), Path(sys.argv[2])))
