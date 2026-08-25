# DESIGN.md — <Proyecto>

Documento impreso, no interfaz. Superficie: PDF A4 generado desde HTML con Chromium headless.

## 1. Intent & North Star

Documento que la organización entrega como PDF impreso.

> Plantilla del sistema `pdf-report`. Ajusta esta sección al documento
> concreto; el resto son invariantes del sistema y no se tocan sin motivo.

El caso base es un documento técnico denso que alguien tiene que leer para decidir algo.
Debe leerse como documentación seria, no como una landing comercial. La autoridad viene
de la densidad de datos y del rigor de la información, no de la decoración.

- **Voz**: analítica, directa, sin adjetivos de marketing. El documento dice qué y por qué.
- **Dirección de arte**: editorial financiera. Portada saturada con la identidad de la marca,
  interior blanco de altísima legibilidad con acentos de marca en reglas, cifras y estados.
- **Anti-referencias**: dossier de agencia con stock photos, pitch deck de startup,
  plantilla corporativa navy/azul genérica, infografías decorativas sin dato detrás.

## 2. Tokens

### Color
Derivados por muestreo directo de `<brand-dir>/banner.png` (identidad existente, se preserva).

| Token | Hex | Rol |
| --- | --- | --- |
| `--ink` | `#17141F` | Texto principal, portada |
| `--ink-soft` | `#4A4055` | Texto secundario (8.1:1 sobre blanco) |
| `--ink-mute` | `#6B6076` | Metadatos y pies (5.4:1 sobre blanco) |
| `--plum-deep` | `#4A2650` | Parada intermedia del degradado |
| `--plum` | `#6E3B6A` | Púrpura de marca, acento primario |
| `--wine` | `#A03349` | Vino de marca, acento de énfasis y riesgo alto |
| `--wine-deep` | `#7A2438` | Cifras destacadas sobre claro |
| `--paper` | `#FFFFFF` | Fondo de página (es papel) |
| `--surface` | `#F7F4F7` | Paneles, tintado hacia `--plum` |
| `--surface-2` | `#EFE9EF` | Cabeceras de tabla, filas alternas |
| `--rule` | `#DED5DE` | Reglas y bordes |
| `--ok` | `#3F6B52` | Riesgo bajo |
| `--warn` | `#A8712A` | Riesgo medio |

Degradado de marca (solo portada, franjas de sección y cierre):
`linear-gradient(105deg, #17141F 0%, #4A2650 38%, #6E3B6A 62%, #A03349 100%)`

**El color nunca es el único indicador.** Los niveles de riesgo y complejidad se
expresan además con una escala de puntos rellenos/vacíos y con etiqueta textual.

### Iconografía
Lucide, embebido como `mask-image` en CSS (no `<img>` ni SVG en línea). Una sola clase
`.ico` aporta la mecánica y `.ico-<nombre>` la forma, de modo que todo icono hereda
`currentColor` y `font-size` y siempre casa con el texto que acompaña. Los trazos
`currentColor` del SVG original se sustituyen por negro sólido: una máscara usa el canal
alfa, y `currentColor` dentro de una máscara no resuelve. Nunca emojis.

### Tipografía
Tres familias, contraste por eje (serif de alto contraste + grotesca + monoespaciada).

- **Display**: `Fraunces` (variable, `opsz`) — portada, títulos de sección, cifras grandes
- **Texto**: `Archivo` — cuerpo, tablas, etiquetas
- **Datos**: `JetBrains Mono` — importes, horas, códigos de módulo

Escala (base 10.5pt para A4):
`micro 7.5pt · small 9pt · body 10.5pt · h3 13pt · h2 19pt · h1 27pt · portada 46pt`

Interlineado de cuerpo 1.55. Longitud de línea 65-72 caracteres.
`letter-spacing` de display: `-0.025em` (nunca por debajo de `-0.04em`).

### Espaciado
Escala de 4pt: `4 · 8 · 12 · 16 · 24 · 32 · 48 · 64`.

### Radio
`2px` en píldoras y celdas, `6px` en paneles. Techo absoluto `8px`.
Los documentos impresos no llevan esquinas muy redondeadas.

## 3. Layout Primitives

- Página A4 exacta: `210mm × 297mm`, maquetada como `section.page` de altura fija.
- Márgenes: `20mm` superior, `18mm` laterales, `16mm` inferior.
- Rejilla interna de 12 columnas, `gap` 6mm.
- Cada página lleva pie propio: marca, confidencialidad y numeración.

## 4. Component Patterns

- **Franja de sección**: barra con el degradado de marca y el número de sección. La
  numeración es informativa porque el informe SÍ es una secuencia leída en orden.
- **Panel de datos** (`.panel`): fondo `--surface`, borde completo `1px --rule`. Sin sombra.
- **Tabla densa**: cabecera `--surface-2`, reglas horizontales de `1px`, cifras en
  monoespaciada alineadas a la derecha, tabular-nums activo.
- **Medidor de complejidad**: cinco puntos, rellenos según nivel, más etiqueta textual.
- **Barra de calendario**: rejilla CSS de 14 columnas, una fila por carril de trabajo.
- **Ficha de persona**: retrato circular de 25mm, nombre y rol. Sin tarjeta contenedora.
  El círculo y su anillo van **horneados en el PNG** (con canal alfa), no aplicados por CSS.

## 5. Densidad

Dos niveles sobre el mismo sistema, no dos sistemas:

- **Normal**: cuerpo 9,3pt, interlineado 1,52, paneles a 5,4mm. Es el valor por defecto.
- **`.page.dense`**: cuerpo 8,9pt, interlineado 1,47, paneles a 4,4mm. Se aplica a las
  páginas que cargan una tabla larga más paneles. Ajusta espaciados, nunca la jerarquía
  ni los colores.

La densidad se elige por página según lo que lleva, jamás recortando contenido que
aporta. Si una página desborda en modo denso, el problema es el reparto de contenido.

## 6. Motion System

**No hay motion.** El artefacto final es un PDF impreso: no existe reproducción temporal.
Cualquier animación en el HTML intermedio sería trabajo muerto y un riesgo de captura
parcial en el renderizado headless. Decisión deliberada, no omisión.

## 7. Accessibility Baselines

- Contraste mínimo 4.5:1 en todo el texto de cuerpo; verificado para `--ink-soft` y
  `--ink-mute` sobre `--paper` y sobre `--surface`.
- El estado (riesgo, complejidad, fase) nunca depende solo del color.
- Estructura de encabezados jerárquica y correcta para lectores de PDF.
- Cuerpo a 10.5pt, por encima del mínimo legible en impresión.

## 8. Anti-patterns (prohibidos en este proyecto)

- Texto con degradado (`background-clip: text`). Decorativo, nunca informativo.
- Bordes laterales de acento (`border-left` de color) como marcador de bloque.
- Glassmorphism, sombras difusas amplias y borde de 1px combinados.
- Emojis como iconografía.
- Paleta corporativa navy/azul genérica: choca con la identidad real de la marca.
- Radios de 24px o superiores en paneles.
- Rayas de `repeating-linear-gradient` como textura de fondo.
- Guiones largos en la redacción.
- Cifras sin fuente ni método declarado. Toda estimación indica su base de cálculo.

## 9. Verificación automática (`render.mjs`)

Ninguna de estas comprobaciones sustituye mirar las páginas, pero todas detectan fallos
que la revisión visual deja pasar:

| Guardia | Qué detecta |
| --- | --- |
| `ICONS` | Clases `.ico-*` usadas en el HTML sin regla en `brand.css` (renderizan como hueco) |
| `OVERFLOW` | Contenido que rebasa su caja A4 |
| `SPARSE` | Más de 150px muertos entre el último bloque y el pie |
| `ORPHAN BLOCKS` | Bloque final corto y suelto tras uno grande: párrafo varado |
| `LOW CONTRAST` | Ratio calculado texto/fondo por debajo de WCAG AA |

El degradado de marca es `background-image` y no se puede leer del árbol: la portada y el
cierre declaran su parada más clara con `data-bg` para que la guardia mida el peor caso.

## 10. Decision Log

Registra aquí cada decisión de diseño propia de este documento. Las heredadas del
sistema están en `~/.claude/skills/pdf-report`.

- **YYYY-MM-DD · <decisión>.** <por qué, y a qué sustituye si aplica>
