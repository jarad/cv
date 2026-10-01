// Typst styling for the CV. Pandoc/Quarto do the layout; this sets the look.
#set text(size: 10pt)
#set par(justify: false, leading: 0.55em)
#set table(stroke: none, inset: (x: 0pt, y: 1pt), row-gutter: 4pt)
#show heading.where(level: 1): it => block(below: 0.9em)[
  #text(size: 19pt, weight: "bold")[#it.body]
  #v(-0.5em)
  #line(length: 100%, stroke: 0.8pt)
]
#show heading.where(level: 2): it => block(above: 1.4em, below: 0.7em, sticky: true)[
  #text(size: 11.5pt, weight: "bold")[#smallcaps[#it.body]]
  #v(-0.5em)
  #line(length: 100%, stroke: 0.4pt + luma(120))
]
#show link: set text(fill: rgb("#1d4ed8"))
