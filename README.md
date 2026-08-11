<div align="center">

# Álvaro´s Dotfiles

### Entorno de terminal y agentes en macOS

Configuración personal centrada en un flujo de trabajo sin salir de la terminal:
tmux, yazi y Ghostty, más Claude Code y OpenCode. Solo material propio: las
skills de terceros no se versionan. La lógica propia está cubierta por tests.

<br/>

![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white&style=flat)
![tmux](https://img.shields.io/badge/tmux-1BB91F?logo=tmux&logoColor=white&style=flat)
![Yazi](https://img.shields.io/badge/Yazi-6366f1?style=flat)
![Ghostty](https://img.shields.io/badge/Ghostty-2E2E2E?style=flat)
![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white&style=flat)
![Neovim](https://img.shields.io/badge/Neovim-57A143?logo=neovim&logoColor=white&style=flat)
![Claude](https://img.shields.io/badge/Claude%20Code-D97757?logo=anthropic&logoColor=white&style=flat)

![visibilidad](https://img.shields.io/badge/visibilidad-privado-red?style=flat)
![tests](https://img.shields.io/badge/tests-190%20passing-22c55e?style=flat)
![enfoque](https://img.shields.io/badge/enfoque-TDD-22c55e?style=flat)

<br/>

[Instalación](#instalación) · [Barra de estado](#barra-de-estado) · [Barra lateral](#barra-lateral-de-archivos) · [Agentes](#agentes) · [Tests](#tests)

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
nada**: si ya tienes una configuración en el destino, la mueve a
`~/.dotfiles-backup/<timestamp>/` antes de enlazar. Volver a ejecutarlo es seguro — los
enlaces que ya apuntan aquí se dejan intactos.

Los backups van a ese directorio aparte, y no junto al original, porque las herramientas
escanean sus carpetas de configuración enteras: un `ship.bak.<timestamp>` dentro de
`~/.claude/skills` se cargaría como una segunda skill duplicada.

| Origen en el repo | Destino |
| --- | --- |
| `config/tmux` | `~/.config/tmux` |
| `config/yazi` | `~/.config/yazi` |
| `config/yazi-sidebar` | `~/.config/yazi-sidebar` |
| `config/ghostty` | `~/.config/ghostty` |
| `home/tmux.conf` | `~/.tmux.conf` |
| `home/zshrc`, `zprofile`, `gitconfig`, `p10k.zsh` | `~/.zshrc`, `~/.zprofile`, `~/.gitconfig`, `~/.p10k.zsh` |
| `config/atuin`, `gh`, `git` | `~/.config/atuin`, `gh`, `git` (por ruta) |
| `shared/skills` | `~/.claude/skills`, `~/.config/opencode/skills`, `~/.opencode/skills` |
| `config/claude/*` | `~/.claude/*` (por ruta) |
| `config/opencode/*` | `~/.config/opencode/*` (por ruta) |

Las configuraciones de agentes se enlazan **ruta por ruta**, nunca el directorio
completo: `~/.claude` guarda además `.credentials.json` y gigabytes de historial de
sesiones, y `~/.config/opencode` guarda `node_modules`. Enlazar el directorio entero
desplazaría todo eso. Hay tests que lo verifican.

### Arranque

Ghostty lanza `config/ghostty/launch.sh`, que resuelve tmux por ruta absoluta y se
adjunta a la sesión compartida. Si tmux no estuviera disponible, cae a una shell de
login: un multiplexor ausente no puede dejarte sin terminal.

La ruta absoluta no es un capricho. Ghostty ejecuta su comando a través de
`/usr/bin/login -flp <usuario> /bin/bash --noprofile --norc`, que hereda el PATH mínimo
de launchd, sin `/opt/homebrew/bin`. Por el mismo motivo, los scripts de tmux y los
comandos que lanzan (yazi, el editor) también se resuelven por ruta absoluta.

`tmux.conf` activa `allow-passthrough on`: yazi envía sondas DA1/DSR al arrancar y, sin
passthrough, tmux las bloquea y yazi espera a agotar su tiempo mostrando
«Terminal response timeout» sobre el panel.

### Herramientas de terminal

`bat`, `zoxide`, `fzf` y `eza` **no tienen fichero de configuración propio**: todo su
ajuste (aliases, `eval "$(zoxide init zsh)"`, `FZF_DEFAULT_COMMAND`, `LS_COLORS`) vive en
`~/.zshrc`, que por eso se versiona. `atuin`, `gh` y `git` sí tienen fichero y van aparte.

Las credenciales no están aquí: se cargan desde `~/.config/zsh/secrets.zsh`, que está
fuera del repositorio. Una suite de tests con `gitleaks` verifica en cada ejecución que
no se ha colado ninguna.

### Dependencias

```bash
brew install tmux yazi neovim bat fd ripgrep sd eza
```

## Qué incluye

```
.
├── shared/
│   └── skills/             Skills propias, independientes de la herramienta
├── config/
│   ├── ghostty/            Tema Tokyo Night, tipografía y quick terminal
│   ├── tmux/               Prefix C-a, navegación vim, popup scratch
│   │   ├── sidebar-toggle.sh
│   │   ├── open-in-work-pane.sh
│   │   ├── statusbar.sh
│   │   └── tests/
│   ├── yazi/               Config de uso general
│   ├── yazi-sidebar/       Config exclusiva de la barra lateral
│   ├── claude/             CLAUDE.md, settings, agentes, comandos, hooks
│   └── opencode/           opencode.json, AGENTS.md, agentes, comandos, plugins
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

## Barra de estado

Fila superior, con cada dato en su propio bloque de color:

```
 target  1 zsh          CPU 13%   GPU 23%   RAM 8.3/16.0G   13:28   11 Aug
```

| Segmento | Color Kanagawa | Fuente del dato |
| --- | --- | --- |
| CPU | crystalBlue | `sysctl vm.loadavg` dividido por núcleos |
| GPU | oniViolet | `ioreg -c AGXAccelerator` → `Device Utilization %` |
| RAM | springGreen | `vm_stat`: active + wired + compressed |
| Hora | carpYellow | `date` |
| Fecha | sakuraPink | `date` |

El color identifica la métrica; nunca es el único portador de información, porque cada
bloque lleva su etiqueta y su valor. Un valor por encima del 85 % cambia a `autumnRed`.

Cuesta **~32 ms por refresco**. La GPU se lee con `ioreg` porque `powermetrics` exige
superusuario y no puede ejecutarse desde un hook de estado. La CPU sale del load average:
muestrear utilización real exige dos lecturas separadas por un `sleep`, que es lo que
hacía que la versión anterior costase segundos.

La barra no tiene fondo propio: `status-style bg=default` hereda el del terminal, así que
la transparencia y el desenfoque de Ghostty se mantienen. Los bloques de color son la
única superficie pintada.

Sin glifos de Nerd Font: solo ASCII, así que la fila no se rompe en un terminal sin
tipografía parcheada. Las reglas completas están en [`.agents/DESIGN.md`](.agents/DESIGN.md).

## Barra lateral de archivos

Tres formas de abrir y cerrar el panel de yazi al 30%: el botón **`[FILES]`** de la barra
superior, `Alt+t`, o `prefix` + `e`. El panel ocupa el 30% a la izquierda de la ventana actual,
heredando su directorio.

Hay dos accesos a propósito. En una distribución **Spanish - ISO**, `Option+E` es la tecla
muerta del acento agudo: macOS la consume para componer `á`/`é` y nunca llega a tmux, así
que `Alt+e` parecía no hacer nada. `Alt+t` no choca con ninguna tecla muerta (son `e`, `i`,
`u`, `n`), y `prefix` + `e` no pasa por `Option` en absoluto.

Ghostty no tiene sistema de plugins — es una decisión de diseño del proyecto, y sus
mantenedores rechazan de forma explícita añadir un árbol de archivos integrado. Tampoco
permite lanzar un comando concreto en un split ni encadenar dos acciones en un atajo.
Por eso la barra lateral vive en tmux: sin proceso gráfico adicional y sin coste cuando
está cerrada.

### Apertura de archivos

Al abrir un archivo desde la barra lateral, se crea una **ventana nueva** de tmux con
`$EDITOR`. Nunca se toca la ventana en la que estabas: lo que tengas corriendo ahí —un
build, un REPL, un editor con cambios sin guardar— sigue igual, sin recibir pulsaciones
ni perder el foco. Al cerrar el editor, la ventana desaparece y vuelves donde estabas.

El editor por defecto es **nano**, para poder cerrar con **`Ctrl+X`** sin escribir ningún
comando. Si el archivo tiene cambios sin guardar, nano pregunta antes de salir. Cámbialo
con `FILE_EDITOR` si prefieres otro.

Este flujo **no sigue a `$EDITOR`** a propósito: ahí tienes `nvim`, que necesita `:q`.

También puedes cerrar con `Alt+w` o `prefix` + `k`, sin escribir el comando de salida del editor.
Solo cierra ventanas abiertas desde la barra lateral: si lo pulsas en una ventana de
trabajo, se niega y te lo dice. Y a un editor de la familia vim le **pide** salir con
`:q` en vez de matarlo, así que si tienes cambios sin guardar decide el editor, no el
atajo.

Fuera de tmux, ejecuta `$EDITOR` en el sitio, así que `yazi` a pantalla completa sigue
funcionando igual.

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

### Skills compartidas

`shared/skills` contiene **solo skills propias**. Son independientes de la herramienta
y se enlazan a los tres destinos a la vez, así que existen una sola vez.

| Skill | Para qué |
| --- | --- |
| `example-org-pdf-report` | Informes y propuestas en PDF A4 con marca |
| `example-org-repo-prep` | Deja un repositorio con la descripción, topics y README de la casa |
| `example-org-video-demo` | Vídeos de demo de producto de 60–90 s |
| `ship` | De árbol de trabajo a PR publicada: commits, PRs encadenadas y revisión |

Las skills instaladas desde marketplaces y packs de terceros **no se versionan aquí**:
cada herramienta las reinstala por su cuenta y mantenerlas duplicadas solo genera
divergencia. Cuando lo estaban, ya había pasado: dos copias de la misma skill medían el
presupuesto de PR con reglas distintas.

### Lo que NO se comparte, y por qué

Los `commands/` y `agents/` son específicos de cada herramienta. No es duplicación
accidental: los de OpenCode llevan frontmatter propio y apuntan a rutas distintas.

```yaml
# config/claude/commands/sdd-apply.md    # config/opencode/commands/sdd-apply.md
---                                      ---
description: Implement SDD tasks         description: Implement SDD tasks
---                                      agent: gentle-orchestrator
                                         subtask: true
                                         ---
```

Son la capa de adaptación entre cada herramienta y las skills compartidas, así que cada
una conserva la suya.

### Configuración por herramienta

| Ruta | Contenido |
| --- | --- |
| `claude/CLAUDE.md` | Instrucciones globales: persona, TDD estricto, pipeline de diseño |
| `claude/sdd-orchestrator.md` | Reglas de orquestación y delegación para SDD |
| `claude/RTK.md`, `MCP-PER-PROJECT.md` | Referencia de herramientas y MCP por proyecto |
| `claude/settings.json` | Permisos, hooks, plugins y marketplaces |
| `claude/agents/`, `commands/`, `hooks/`, `prompts/` | Subagentes, comandos y hooks |
| `opencode/opencode.json`, `AGENTS.md` | Configuración y instrucciones globales |
| `opencode/agents/`, `commands/`, `plugin/`, `plugins/`, `profiles/`, `prompts/` | Adaptadores y extensiones |

## Tests

```bash
./tests/run-all.sh
```

```
install                39 passed, 0 failed
launch                 12 passed, 0 failed
sidebar-toggle         12 passed, 0 failed
open-file              17 passed, 0 failed
close-file              8 passed, 0 failed
yazi-sidebar-config    10 passed, 0 failed
statusbar              29 passed, 0 failed
status-style            7 passed, 0 failed
keybindings            10 passed, 0 failed
sidebar-button         10 passed, 0 failed

160 passed, 0 failed
```

Cada suite levanta su propio servidor de tmux aislado (`tmux -L`) y, en el caso de
`install`, un `$HOME` desechable. Ninguna toca tu sesión ni tu configuración real.

Las suites de tmux y yazi comprueban la configuración **instalada** en `~/.config`, así
que ejecuta `./install.sh` antes de lanzarlas en una máquina nueva.

Dos comprobaciones que conviene conservar:

- `install` verifica que `~/.claude` sigue siendo un directorio real tras la instalación
  y que `.credentials.json` y `projects/` quedan intactos. También comprueba que los
  tres destinos de skills resuelven a **una única fuente**, para que no puedan volver a
  divergir.
- `yazi-sidebar-config` verifica que las dos configuraciones de yazi no divergen.
  `YAZI_CONFIG_HOME` reemplaza a `~/.config/yazi` en lugar de fusionarse con ella, así
  que el `opener` está duplicado a propósito y el test falla si una copia se queda atrás.
