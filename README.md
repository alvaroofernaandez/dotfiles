<div align="center">

# Álvaro´s Dotfiles

### Entorno de terminal y agentes en macOS

Configuración personal centrada en un flujo de trabajo sin salir de la terminal:
tmux, yazi y Ghostty, más la configuración completa de Claude Code y OpenCode
con sus skills, agentes y comandos. La lógica propia está cubierta por tests.

<br/>

![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white&style=flat)
![tmux](https://img.shields.io/badge/tmux-1BB91F?logo=tmux&logoColor=white&style=flat)
![Yazi](https://img.shields.io/badge/Yazi-6366f1?style=flat)
![Ghostty](https://img.shields.io/badge/Ghostty-2E2E2E?style=flat)
![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white&style=flat)
![Neovim](https://img.shields.io/badge/Neovim-57A143?logo=neovim&logoColor=white&style=flat)
![Claude](https://img.shields.io/badge/Claude%20Code-D97757?logo=anthropic&logoColor=white&style=flat)

![visibilidad](https://img.shields.io/badge/visibilidad-privado-red?style=flat)
![tests](https://img.shields.io/badge/tests-68%20passing-22c55e?style=flat)
![enfoque](https://img.shields.io/badge/enfoque-TDD-22c55e?style=flat)

<br/>

[Instalación](#instalación) · [Qué incluye](#qué-incluye) · [Barra lateral](#barra-lateral-de-archivos) · [Agentes](#agentes) · [Tests](#tests)

</div>

---

## Instalación

```bash
git clone git@github.com:alvaroofernaandez/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run   # revisa qué haría
./install.sh             # enlaza de verdad
```

`install.sh` crea enlaces simbólicos desde `$HOME` hacia este repositorio. **Nunca borra
nada**: si ya tienes una configuración en el destino, la mueve a `<ruta>.bak.<timestamp>`
antes de enlazar. Volver a ejecutarlo es seguro — los enlaces que ya apuntan aquí se
dejan intactos.

| Origen en el repo | Destino |
| --- | --- |
| `config/tmux` | `~/.config/tmux` |
| `config/yazi` | `~/.config/yazi` |
| `config/yazi-sidebar` | `~/.config/yazi-sidebar` |
| `config/ghostty` | `~/.config/ghostty` |
| `home/tmux.conf` | `~/.tmux.conf` |
| `config/claude/*` | `~/.claude/*` (por ruta) |
| `config/opencode/*` | `~/.config/opencode/*` (por ruta) |
| `config/opencode-home/skills` | `~/.opencode/skills` |

Las configuraciones de agentes se enlazan **ruta por ruta**, nunca el directorio
completo: `~/.claude` guarda además `.credentials.json` y gigabytes de historial de
sesiones, y `~/.config/opencode` guarda `node_modules`. Enlazar el directorio entero
desplazaría todo eso. Hay tests que lo verifican.

### Dependencias

```bash
brew install tmux yazi neovim bat fd ripgrep sd eza
```

## Qué incluye

```
.
├── config/
│   ├── ghostty/            Tema Tokyo Night, tipografía y quick terminal
│   ├── tmux/               Prefix C-a, navegación vim, popup scratch
│   │   ├── sidebar-toggle.sh
│   │   ├── open-in-work-pane.sh
│   │   ├── metrics.sh
│   │   └── tests/
│   ├── yazi/               Config de uso general
│   ├── yazi-sidebar/       Config exclusiva de la barra lateral
│   ├── claude/             CLAUDE.md, settings, skills, agentes, comandos, hooks
│   ├── opencode/           opencode.json, AGENTS.md, skills, agentes, plugins
│   └── opencode-home/      Skills de ~/.opencode
├── home/tmux.conf
├── install.sh
└── tests/
```

### Fuera del repositorio a propósito

| Ruta | Motivo |
| --- | --- |
| `~/.claude/.credentials.json` | Credenciales |
| `~/.local/share/opencode/auth.json` | Credenciales |
| `~/.local/share/opencode/mcp-auth.json` | Credenciales |
| `~/.claude/projects`, `history.jsonl`, `file-history` | Historial de sesiones (1,6 GB) |
| `~/.local/share/opencode/opencode.db` | Base de datos local (4,5 GB) |
| `~/.claude/settings.local.json` | Permisos locales de una máquina concreta |
| `node_modules`, `*.bak` | Regenerables |

## Barra lateral de archivos

`Alt+e` abre y cierra un panel de yazi al 30% a la izquierda de la ventana actual,
heredando su directorio.

Ghostty no tiene sistema de plugins — es una decisión de diseño del proyecto, y sus
mantenedores rechazan de forma explícita añadir un árbol de archivos integrado. Tampoco
permite lanzar un comando concreto en un split ni encadenar dos acciones en un atajo.
Por eso la barra lateral vive en tmux: sin proceso gráfico adicional y sin coste cuando
está cerrada.

### Apertura de archivos

Al abrir un archivo desde la barra lateral, el editor **no** se lanza en el panel
estrecho. El script decide según lo que esté corriendo en tu panel de trabajo:

| Estado del panel de trabajo | Comportamiento |
| --- | --- |
| Shell (`zsh`, `bash`, `fish`…) | Ejecuta `$EDITOR -- <archivos>` y le pasa el foco |
| `nvim` o `vim` ya abierto | Lo reutiliza con `:edit` / `:badd`, sin anidar otro editor |
| Cualquier otro proceso | Se niega y sale con error |
| Fuera de tmux o sin panel destino | Abre `$EDITOR` en el sitio |

Esa tercera fila es deliberada: si tienes un build o un REPL en marcha, enviar teclas a
ciegas inyectaría texto dentro de ese proceso.

### Ajustes

| Variable | Por defecto | Para qué |
| --- | --- | --- |
| `SIDEBAR_CMD` | `yazi` | Programa que se ejecuta en la barra lateral |
| `SIDEBAR_WIDTH` | `30%` | Ancho del panel |
| `SIDEBAR_CONFIG_HOME` | `~/.config/yazi-sidebar` | Config de yazi propia del panel |

La barra lateral usa su propia configuración de yazi con `ratio = [0, 1, 0]`: a 60
columnas, el diseño de tres columnas por defecto trunca todos los nombres. Aquí el ancho
completo va al árbol, y la previsualización la da el panel de trabajo al abrir el archivo.

## Agentes

### Claude Code

| Ruta | Contenido |
| --- | --- |
| `CLAUDE.md` | Instrucciones globales: persona, TDD estricto, pipeline de diseño |
| `sdd-orchestrator.md` | Reglas de orquestación y delegación para SDD |
| `RTK.md`, `MCP-PER-PROJECT.md` | Referencia de herramientas y MCP por proyecto |
| `settings.json` | Permisos, hooks, plugins y marketplaces |
| `skills/` | 70 skills |
| `agents/`, `commands/`, `hooks/`, `prompts/` | Subagentes, comandos y hooks |

### OpenCode

`opencode.json`, `AGENTS.md`, y los directorios `skills/`, `agents/`, `commands/`,
`plugin/`, `plugins/`, `profiles/` y `prompts/`, más las skills de `~/.opencode`.

## Tests

```bash
./tests/run-all.sh
```

```
install                32 passed, 0 failed
sidebar-toggle         12 passed, 0 failed
open-in-work-pane      14 passed, 0 failed
yazi-sidebar-config    10 passed, 0 failed

68 passed, 0 failed
```

Cada suite levanta su propio servidor de tmux aislado (`tmux -L`) y, en el caso de
`install`, un `$HOME` desechable. Ninguna toca tu sesión ni tu configuración real.

Las suites de tmux y yazi comprueban la configuración **instalada** en `~/.config`, así
que ejecuta `./install.sh` antes de lanzarlas en una máquina nueva.

Dos comprobaciones que conviene conservar:

- `install` verifica que `~/.claude` sigue siendo un directorio real tras la instalación
  y que `.credentials.json` y `projects/` quedan intactos.
- `yazi-sidebar-config` verifica que las dos configuraciones de yazi no divergen.
  `YAZI_CONFIG_HOME` reemplaza a `~/.config/yazi` en lugar de fusionarse con ella, así
  que el `opener` está duplicado a propósito y el test falla si una copia se queda atrás.
