# Component catalogue

Copy-paste blocks. Every one is already styled by `report.css`; you only write structure.

## Page shell

```html
<section class="page">                <!-- add class="dense" when heavily loaded -->
  <div class="sec"><span class="n">01</span><h2>Título</h2><span class="of">Página 2 de 16</span></div>
  ...
  <div class="foot"><span class="brand"><span class="mark"></span> <Organización> · Proyecto</span><span>Confidencial · uso interno</span><span class="num">02 / 16</span></div>
</section>
```

The footer is manual on every page. That is deliberate: it is what lets each page carry
its own numbering and confidentiality mark without fighting the print engine.

## The answer block

Opens every section. Dark, one sentence in bold, consequence after.

```html
<div class="answer">
  <span class="ico ico-triangle-alert"></span>
  <p><strong>La conclusión.</strong> La consecuencia práctica.</p>
</div>
```

## Panels

```html
<div class="panel">          <!-- neutral -->
<div class="panel panel-ink">  <!-- dark, for the point you want remembered -->
<div class="panel panel-ok">   <!-- green, favourable -->
<div class="panel panel-warn"> <!-- amber, caution -->
<div class="panel panel-wine"> <!-- red, problem -->
```

With a heading and an icon:

```html
<div class="panel panel-ok">
  <h3><span class="ico ico-circle-check"></span>Título</h3>
  <p class="small mt2">Texto.</p>
</div>
```

## Figures

```html
<div class="panel">
  <div class="figure">
    <span class="val wine">9,9&nbsp;%</span>   <!-- .val.sm for a smaller one -->
    <span class="lab">Qué mide y por qué importa.</span>
  </div>
</div>
```

## Icon lists

```html
<ul class="ico-list ok">      <!-- .ok green · .no wine · omit for plum -->
  <li><span class="ico ico-circle-check"></span><span>Texto del punto.</span></li>
</ul>
```

## Numbered steps

```html
<ol class="steps">
  <li><strong>Título.</strong> Explicación.</li>
</ol>
```

Add `style="display:grid;grid-template-columns:repeat(3,1fr);gap:0 6mm"` to lay the
steps out in columns instead of a stack.

## Tables

```html
<table>
  <caption>Rótulo en versalitas</caption>
  <thead><tr><th style="width:8mm"></th><th>Concepto</th><th class="r">Importe</th></tr></thead>
  <tbody>
    <tr><td class="c"><span class="ico ico-euro"></span></td><td><strong>Fila</strong><br><span class="micro mute">Matiz</span></td><td class="n r">1.234&nbsp;€</td></tr>
  </tbody>
  <tfoot><tr class="t-total"><td colspan="2">Total</td><td class="n r">1.234&nbsp;€</td></tr></tfoot>
</table>
```

`.n` for figures (monospace, tabular), `.r` right, `.c` centre. `.t-total` paints the
row dark: use it once per table, on the number that matters.

## Module card

The workhorse. Keep the row order fixed across every card in the document.

```html
<div class="mod">
  <div class="mod-hd">
    <span class="ico ico-database"></span><span class="code">M12</span>
    <h3>Nombre</h3>
    <div class="gauges">
      <div class="g"><span class="k">Complejidad</span><span class="meter"><i class="on"></i><i class="on"></i><i class="on"></i><i></i><i></i></span></div>
      <div class="g"><span class="k">Riesgo</span><span class="meter risk"><i class="on"></i><i class="on"></i><i></i><i></i><i></i></span></div>
    </div>
  </div>
  <div class="mod-bd">
    <div class="mod-row"><span class="k">Qué hace</span><span class="v">Una frase.</span></div>
    <div class="mod-row"><span class="k">Esfuerzo</span><span class="v num" style="font-size:8.6pt">38&nbsp;h · 2.128&nbsp;€ · Fase 1</span></div>
    <div class="mod-row"><span class="k">La trampa</span><span class="v">Lo que nadie estima.</span></div>
    <div class="mod-row dec"><span class="k">Decisión</span><span class="v">Qué decidimos y por qué.</span></div>
  </div>
</div>
```

To flag a card as critical, add `style="border-color:var(--wine-line)"` to `.mod` and
`style="background:var(--wine-bg);border-color:var(--wine-line)"` to `.mod-hd`.

## Meters and pills

```html
<span class="meter"><i class="on"></i><i class="on"></i><i></i><i></i><i></i></span>
<span class="meter risk">...</span>          <!-- wine instead of plum -->
<span class="lvl lvl-low|lvl-mid|lvl-high">Bajo</span>

<span class="pill pill-ok"><span class="ico ico-circle-check"></span>Favorable</span>
<span class="pill pill-warn|pill-wine|pill-out">…</span>
```

Colour is never the only signal: the filled dots and the text label both carry it.

## Compared options

```html
<div class="grid3">
  <div class="opt pick">                     <!-- .pick outlines the recommendation -->
    <span class="pill pill-ok" style="align-self:flex-start"><span class="ico ico-circle-check"></span>Recomendada</span>
    <span class="t">A · Nombre</span>
    <div class="price">2.400&nbsp;€</div>     <!-- .price.no greys out a rejected one -->
    <div class="meta">35&nbsp;h · 2 semanas</div>
    <ul class="ico-list ok" style="gap:1.6mm"><li>…</li></ul>
    <p class="micro mute" style="margin-top:auto"><strong>Después:</strong> …</p>
  </div>
</div>
```

## Comparison bars

Widths are percentages of the largest value. Compute them; do not eyeball them.

```html
<div class="compare">
  <div class="cmp-row">
    <div class="cmp-lab">Etiqueta<br><span class="micro mute">Matiz</span></div>
    <div class="cmp-track"><div class="cmp-fill" style="width:52.6%;background:var(--plum)">29.800&nbsp;€</div></div>
    <div class="cmp-val">29.800</div>
  </div>
</div>
```

White text inside a fill needs a background at least as dark as `#9E5567`.

## Timeline

One `.g-row` per lane. The header row sets the week columns; column 1 is the label, so
week N lives in column N+1.

```html
<div class="gantt">
  <div class="g-row"><div></div><div class="hd">S1</div>…<div class="hd">S12</div></div>
  <div class="g-row">
    <div class="lane"><span class="ico ico-lock"></span>Nombre del carril</div>
    <div class="bar b-ink" style="grid-column:2/4">Etiqueta</div>
  </div>
</div>
```

Bar colours: `b-ink` `b-deep` `b-plum` `b-wine` `b-ghost`. Change the week count in the
header and in `.g-row`'s `grid-template-columns` together, or the bars will lie.

## Tier cards

For any set of options the reader has to choose between — plans, levels, scenarios,
alternatives. Mark at most one with `.pick`; two recommendations is no recommendation.

```html
<div class="plan pick">                    <!-- .pick for the recommended tier -->
  <span class="tagpick">Etiqueta corta</span>
  <div class="nm">Nombre del nivel</div>
  <div class="pr">&lt;cifra&gt; <small>/unidad</small></div>
  <ul><li><span class="ico ico-clock"></span><span>Qué incluye este nivel</span></li></ul>
</div>
```

## Icons

40 Lucide icons, as `<span class="ico ico-<name>"></span>`. They inherit `currentColor`
and `font-size`, so they always match their text.

`triangle-alert` `circle-check` `circle-x` `clock` `euro` `users` `layers` `database`
`shopping-cart` `smartphone` `file-pen-line` `search` `shield-check` `trending-up`
`git-branch` `zap` `target` `lightbulb` `lock` `handshake` `wrench` `gauge` `map`
`arrow-right` `scan-barcode` `store` `credit-card` `ban` `calendar-clock` `hourglass`
`signature` `circle-help` `flag` `route` `chart-column` `package` `banknote` `milestone`
`square-check-big` `minus`

Need another? Add it to the `ICONS` list in `build-assets.py` and rebuild. Never emojis.

## Utilities

`.small` `.micro` `.mute` `.num` `.wine` · `.mt2`–`.mt6` `.mb3`–`.mb6` ·
`.grid2` `.grid3` `.stack`
