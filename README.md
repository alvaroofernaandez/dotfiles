<div align="center">

# dotfiles

### Entorno de terminal en macOS: tmux, yazi y Ghostty

Configuración personal centrada en un flujo de trabajo sin salir de la terminal.
Incluye una barra lateral de archivos plegable construida sobre tmux, con toda su
lógica cubierta por tests.

<br/>

![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white&style=flat)
![tmux](https://img.shields.io/badge/tmux-1BB91F?logo=tmux&logoColor=white&style=flat)
![Yazi](https://img.shields.io/badge/Yazi-6366f1?style=flat)
![Ghostty](https://img.shields.io/badge/Ghostty-2E2E2E?style=flat)
![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white&style=flat)
![Neovim](https://img.shields.io/badge/Neovim-57A143?logo=neovim&logoColor=white&style=flat)

![visibilidad](https://img.shields.io/badge/visibilidad-privado-red?style=flat)
![tests](https://img.shields.io/badge/tests-56%20passing-22c55e?style=flat)
![enfoque](https://img.shields.io/badge/enfoque-TDD-22c55e?style=flat)

<br/>

[Instalación](#instalación) · [Qué incluye](#qué-incluye) · [Barra lateral](#barra-lateral-de-archivos) · [Tests](#tests)

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
│   └── yazi-sidebar/       Config exclusiva de la barra lateral
├── home/tmux.conf
├── install.sh
└── tests/
```

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

## Tests

```bash
./tests/run-all.sh
```

```
install                20 passed, 0 failed
sidebar-toggle         12 passed, 0 failed
open-in-work-pane      14 passed, 0 failed
yazi-sidebar-config    10 passed, 0 failed

56 passed, 0 failed
```

Cada suite levanta su propio servidor de tmux aislado (`tmux -L`) y, en el caso de
`install`, un `$HOME` desechable. Ninguna toca tu sesión ni tu configuración real.

Las suites de tmux y yazi comprueban la configuración **instalada** en `~/.config`, así
que ejecuta `./install.sh` antes de lanzarlas en una máquina nueva.

Un detalle que conviene conservar: `yazi-sidebar-config` verifica que las dos
configuraciones de yazi no divergan. `YAZI_CONFIG_HOME` reemplaza a `~/.config/yazi` en
lugar de fusionarse con ella, así que el `opener` está duplicado a propósito y el test
falla si alguna de las dos copias se queda atrás.
