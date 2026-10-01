-- Pandoc filter that gives the CV's few structural classes a native look in
-- each output format. The R code only ever says *what* something is
-- (a row of dates and text, a hanging-indent reference, a "new" tag); this is
-- the one place that knows how each format draws it.
--
--   .cv-rows     a definition list -> a borderless two-column table
--   .cv-list     references with a hanging indent, each kept on one page
--   .cv-group    a label and its rows, kept together on one page
--   .cv-tree     nested bullets, each item kept whole on one page
--   .cv-table    a real table with a header row; .cv-keep keeps it on one page
--   .cv-new      the NEW tag

local is_typst = FORMAT:match('typst')

local function rows_to_table(dl)
  local rows = {}
  for _, item in ipairs(dl.content) do
    local term, defs = item[1], item[2]
    rows[#rows + 1] = { { pandoc.Plain(term) }, defs[1] }
  end
  local st = pandoc.SimpleTable(
    pandoc.Inlines({}),
    { pandoc.AlignLeft, pandoc.AlignLeft },
    { 0.19, 0.81 },
    {}, rows)
  return pandoc.utils.from_simple_table(st)
end

-- a bullet's own text is unbreakable; the lists nested inside it are not, so a
-- group of items can still run across a page
local function keep_items(list)
  local items = pandoc.List()
  for _, item in ipairs(list.content) do
    local out, nested = pandoc.List({ pandoc.RawBlock('typst', '#block(breakable: false)[') }), pandoc.List()
    for _, b in ipairs(item) do
      if b.t == 'BulletList' then nested:insert(keep_items(b)) else out:insert(b) end
    end
    out:insert(pandoc.RawBlock('typst', ']'))
    -- close the paragraph-sized gap between a group and its items
    if #nested > 0 then out:insert(pandoc.RawBlock('typst', '#v(-0.65em)')) end
    out:extend(nested)
    items:insert(out)
  end
  return pandoc.BulletList(items)
end

function Div(el)
  if el.classes:includes('cv-rows') then
    local out = pandoc.List()
    for _, b in ipairs(el.content) do
      if b.t == 'DefinitionList' then out:insert(rows_to_table(b)) else out:insert(b) end
    end
    return out
  end

  -- an entry must never be split across pages: each goes in an unbreakable
  -- block. (Word does this with "keep lines together" on the CV Entry style.)
  if is_typst and el.classes:includes('cv-list') then
    local out = pandoc.List({ pandoc.RawBlock('typst',
      '#[#set par(hanging-indent: 1.4em)\n#set block(spacing: 1em)') })
    for _, b in ipairs(el.content) do
      out:insert(pandoc.RawBlock('typst', '#block(breakable: false)['))
      out:insert(b)
      out:insert(pandoc.RawBlock('typst', ']'))
    end
    out:insert(pandoc.RawBlock('typst', ']'))
    return out
  end

  -- the blocks that keep an item whole make the list loose, so its spacing is
  -- set explicitly, to what a tight list has
  if is_typst and el.classes:includes('cv-tree') then
    local out = pandoc.List({ pandoc.RawBlock('typst', '#[#set list(spacing: 0.55em)') })
    for _, b in ipairs(el.content) do
      out:insert(b.t == 'BulletList' and keep_items(b) or b)
    end
    out:insert(pandoc.RawBlock('typst', ']'))
    return out
  end

  -- room to the right of each cell (a gutter would push a full-width table past
  -- the margin), ragged right without hyphenation, a bold header, and a rule under it
  if is_typst and el.classes:includes('cv-table') then
    local keep = el.classes:includes('cv-keep')
    local out = pandoc.List({ pandoc.RawBlock('typst',
      '#[#set table(row-gutter: 0pt, column-gutter: 0pt, inset: (left: 0pt, right: 0.7em, y: 2.5pt))\n' ..
      '#set par(justify: false)\n#set text(hyphenate: false)\n' ..
      '#show table.cell.where(y: 0): set text(weight: "bold")' ..
      (keep and '\n#block(breakable: false)[' or '')) })
    out:extend(el.content)
    out:insert(pandoc.RawBlock('typst', keep and ']]' or ']'))
    return out
  end

  -- Word: pandoc sets every cell's paragraph style itself, so the smaller text
  -- and the bold header are character styles on the text inside the cells
  if FORMAT:match('docx') and el.classes:includes('cv-table') then
    local function restyle(cells, style)
      for _, cell in ipairs(cells) do
        for _, b in ipairs(cell.contents) do
          if b.t == 'Plain' or b.t == 'Para' then
            b.content = { pandoc.Span(b.content, pandoc.Attr('', {}, { ['custom-style'] = style })) }
          end
        end
      end
    end
    for _, b in ipairs(el.content) do
      if b.t == 'Table' then
        for _, row in ipairs(b.head.rows) do restyle(row.cells, 'CV Table Head') end
        for _, body in ipairs(b.bodies) do
          for _, row in ipairs(body.body) do restyle(row.cells, 'CV Table Text') end
        end
      end
    end
    return el.content
  end

  if is_typst and el.classes:includes('cv-group') then
    local out = pandoc.List({ pandoc.RawBlock('typst', '#block(breakable: false)[') })
    out:extend(el.content)
    out:insert(pandoc.RawBlock('typst', ']'))
    return out
  end
end

function Span(el)
  if el.classes:includes('cv-new') then
    if is_typst then
      return pandoc.RawInline('typst',
        '#text(size: 7pt, weight: "bold", fill: rgb("#9a3412"), tracking: 0.5pt)[NEW]')
    end
    el.attributes['custom-style'] = 'CV New'
    return el
  end
end
