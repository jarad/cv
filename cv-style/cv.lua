-- Pandoc filter that gives the CV's few structural classes a native look in
-- each output format. The R code only ever says *what* something is
-- (a row of dates and text, a hanging-indent reference, a "new" tag); this is
-- the one place that knows how each format draws it.
--
--   .cv-rows     a definition list -> a borderless two-column table
--   .cv-list     references with a hanging indent, each kept on one page
--   .cv-group    a label and its rows, kept together on one page
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
