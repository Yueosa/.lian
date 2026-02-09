" Sakurine Theme: {{{
"
" Based on Dracula, customized for sakurine palette.
" MIT license.
"
" }}}}

" Configuration: {{{

if v:version > 580
  highlight clear
  if exists('syntax_on')
    syntax reset
  endif
endif

let g:colors_name = 'sakurine'

if !(has('termguicolors') && &termguicolors) && !has('gui_running') && &t_Co != 256
  finish
endif

" Palette: {{{2

let s:fg        = g:sakurine#palette.fg

let s:bglighter = g:sakurine#palette.bglighter
let s:bglight   = g:sakurine#palette.bglight
let s:bg        = g:sakurine#palette.bg
let s:bgdark    = g:sakurine#palette.bgdark
let s:bgdarker  = g:sakurine#palette.bgdarker

let s:comment   = g:sakurine#palette.comment
let s:selection = g:sakurine#palette.selection
let s:subtle    = g:sakurine#palette.subtle

let s:cyan      = g:sakurine#palette.cyan
let s:green     = g:sakurine#palette.green
let s:orange    = g:sakurine#palette.orange
let s:pink      = g:sakurine#palette.pink
let s:purple    = g:sakurine#palette.purple
let s:red       = g:sakurine#palette.red
let s:yellow    = g:sakurine#palette.yellow

let s:none      = ['NONE', 'NONE']

if has('nvim')
  for s:i in range(16)
    let g:terminal_color_{s:i} = g:sakurine#palette['color_' . s:i]
  endfor
endif

if has('terminal')
  let g:terminal_ansi_colors = []
  for s:i in range(16)
    call add(g:terminal_ansi_colors, g:sakurine#palette['color_' . s:i])
  endfor
endif

" }}}2
" User Configuration: {{{2

if !exists('g:sakurine_bold')
  let g:sakurine_bold = 1
endif

if !exists('g:sakurine_italic')
  let g:sakurine_italic = 1
endif

if !exists('g:sakurine_strikethrough')
  let g:sakurine_strikethrough = 1
endif

if !exists('g:sakurine_underline')
  let g:sakurine_underline = 1
endif

if !exists('g:sakurine_undercurl')
  let g:sakurine_undercurl = g:sakurine_underline
endif

if !exists('g:sakurine_full_special_attrs_support')
  let g:sakurine_full_special_attrs_support = has('gui_running')
endif

if !exists('g:sakurine_inverse')
  let g:sakurine_inverse = 1
endif

if !exists('g:sakurine_colorterm')
  let g:sakurine_colorterm = 1
endif

if !exists('g:sakurine_high_contrast_diff')
  let g:sakurine_high_contrast_diff = 0
endif

"}}}2
" Script Helpers: {{{2

let s:attrs = {
      \ 'bold': g:sakurine_bold == 1 ? 'bold' : 0,
      \ 'italic': g:sakurine_italic == 1 ? 'italic' : 0,
      \ 'strikethrough': g:sakurine_strikethrough == 1 ? 'strikethrough' : 0,
      \ 'underline': g:sakurine_underline == 1 ? 'underline' : 0,
      \ 'undercurl': g:sakurine_undercurl == 1 ? 'undercurl' : 0,
      \ 'inverse': g:sakurine_inverse == 1 ? 'inverse' : 0,
      \}

function! s:h(scope, fg, ...) " bg, attr_list, special
  let l:fg = copy(a:fg)
  let l:bg = get(a:, 1, ['NONE', 'NONE'])

  let l:attr_list = filter(get(a:, 2, ['NONE']), 'type(v:val) == 1')
  let l:attrs = len(l:attr_list) > 0 ? join(l:attr_list, ',') : 'NONE'

  " If the UI does not have full support for special attributes (like underline and
  " undercurl) and the highlight does not explicitly set the foreground color,
  " make the foreground the same as the attribute color to ensure the user will
  " get some highlight if the attribute is not supported. The default behavior
  " is to assume that terminals do not have full support, but the user can set
  " the global variable `g:sakurine_full_special_attrs_support` explicitly if the
  " default behavior is not desirable.
  let l:special = get(a:, 3, ['NONE', 'NONE'])
  if l:special[0] !=# 'NONE' && l:fg[0] ==# 'NONE' && !g:sakurine_full_special_attrs_support
    let l:fg[0] = l:special[0]
    let l:fg[1] = l:special[1]
  endif

  let l:hl_string = [
        \ 'highlight', a:scope,
        \ 'guifg=' . l:fg[0], 'ctermfg=' . l:fg[1],
        \ 'guibg=' . l:bg[0], 'ctermbg=' . l:bg[1],
        \ 'gui=' . l:attrs, 'cterm=' . l:attrs,
        \ 'guisp=' . l:special[0],
        \]

  execute join(l:hl_string, ' ')
endfunction

"}}}2
" Sakurine Highlight Groups: {{{2

call s:h('SakurineBgLight', s:none, s:bglight)
call s:h('SakurineBgLighter', s:none, s:bglighter)
call s:h('SakurineBgDark', s:none, s:bgdark)
call s:h('SakurineBgDarker', s:none, s:bgdarker)

call s:h('SakurineFg', s:fg)
call s:h('SakurineFgUnderline', s:fg, s:none, [s:attrs.underline])
call s:h('SakurineFgBold', s:fg, s:none, [s:attrs.bold])
call s:h('SakurineFgStrikethrough', s:fg, s:none, [s:attrs.strikethrough])

call s:h('SakurineComment', s:comment)
call s:h('SakurineCommentBold', s:comment, s:none, [s:attrs.bold])

call s:h('SakurineSelection', s:none, s:selection)

call s:h('SakurineSubtle', s:subtle)

call s:h('SakurineCyan', s:cyan)
call s:h('SakurineCyanItalic', s:cyan, s:none, [s:attrs.italic])

call s:h('SakurineGreen', s:green)
call s:h('SakurineGreenBold', s:green, s:none, [s:attrs.bold])
call s:h('SakurineGreenItalic', s:green, s:none, [s:attrs.italic])
call s:h('SakurineGreenItalicUnderline', s:green, s:none, [s:attrs.italic, s:attrs.underline])

call s:h('SakurineOrange', s:orange)
call s:h('SakurineOrangeBold', s:orange, s:none, [s:attrs.bold])
call s:h('SakurineOrangeItalic', s:orange, s:none, [s:attrs.italic])
call s:h('SakurineOrangeBoldItalic', s:orange, s:none, [s:attrs.bold, s:attrs.italic])
call s:h('SakurineOrangeInverse', s:bg, s:orange)

call s:h('SakurinePink', s:pink)
call s:h('SakurinePinkItalic', s:pink, s:none, [s:attrs.italic])

call s:h('SakurinePurple', s:purple)
call s:h('SakurinePurpleBold', s:purple, s:none, [s:attrs.bold])
call s:h('SakurinePurpleItalic', s:purple, s:none, [s:attrs.italic])

call s:h('SakurineRed', s:red)
call s:h('SakurineRedInverse', s:fg, s:red)

call s:h('SakurineYellow', s:yellow)
call s:h('SakurineYellowBold', s:yellow, s:none, [s:attrs.bold])
call s:h('SakurineYellowItalic', s:yellow, s:none, [s:attrs.italic])

call s:h('SakurineError', s:red, s:none, [], s:red)

call s:h('SakurineErrorLine', s:none, s:none, [s:attrs.undercurl], s:red)
call s:h('SakurineWarnLine', s:none, s:none, [s:attrs.undercurl], s:orange)
call s:h('SakurineInfoLine', s:none, s:none, [s:attrs.undercurl], s:cyan)

call s:h('SakurineTodo', s:cyan, s:none, [s:attrs.bold, s:attrs.inverse])
call s:h('SakurineSearch', s:green, s:none, [s:attrs.inverse])
call s:h('SakurineBoundary', s:comment, s:bgdark)
call s:h('SakurineWinSeparator', s:comment, s:bgdark)
call s:h('SakurineLink', s:cyan, s:none, [s:attrs.underline])

if g:sakurine_high_contrast_diff
  call s:h('SakurineDiffChange', s:yellow, s:purple)
  call s:h('SakurineDiffDelete', s:bgdark, s:red)
else
  call s:h('SakurineDiffChange', s:orange, s:none)
  call s:h('SakurineDiffDelete', s:red, s:bgdark)
endif

call s:h('SakurineDiffText', s:bg, s:orange)
call s:h('SakurineInlayHint', s:comment, s:bgdark)

" }}}2

" }}}
" User Interface: {{{

set background=dark

" Required as some plugins will overwrite
call s:h('Normal', s:fg, g:sakurine_colorterm || has('gui_running') ? s:bg : s:none )
call s:h('StatusLine', s:none, s:bglighter, [s:attrs.bold])
call s:h('StatusLineNC', s:none, s:bglight)
call s:h('StatusLineTerm', s:none, s:bglighter, [s:attrs.bold])
call s:h('StatusLineTermNC', s:none, s:bglight)
call s:h('WildMenu', s:bg, s:purple, [s:attrs.bold])
call s:h('CursorLine', s:none, s:subtle)

hi! link ColorColumn  SakurineBgDark
hi! link CursorColumn CursorLine
hi! link CursorLineNr SakurineYellow
hi! link DiffAdd      SakurineGreen
hi! link DiffAdded    DiffAdd
hi! link DiffChange   SakurineDiffChange
hi! link DiffDelete   SakurineDiffDelete
hi! link DiffRemoved  DiffDelete
hi! link DiffText     SakurineDiffText
hi! link Directory    SakurinePurpleBold
hi! link ErrorMsg     SakurineRedInverse
hi! link FoldColumn   SakurineSubtle
hi! link Folded       SakurineBoundary
hi! link IncSearch    SakurineOrangeInverse
call s:h('LineNr', s:comment)
hi! link MoreMsg      SakurineFgBold
hi! link NonText      SakurineSubtle
hi! link Pmenu        SakurineBgDark
hi! link PmenuSbar    SakurineBgDark
hi! link PmenuSel     SakurineSelection
hi! link PmenuThumb   SakurineSelection
call s:h('PmenuMatch', s:cyan, s:bgdark)
call s:h('PmenuMatchSel', s:cyan, s:selection)
hi! link Question     SakurineFgBold
hi! link Search       SakurineSearch
call s:h('SignColumn', s:comment)
hi! link TabLine      SakurineBoundary
hi! link TabLineFill  SakurineBgDark
hi! link TabLineSel   Normal
hi! link Title        SakurineGreenBold
hi! link VertSplit    SakurineWinSeparator
hi! link Visual       SakurineSelection
hi! link VisualNOS    Visual
hi! link WarningMsg   SakurineOrangeInverse

" }}}
" Syntax: {{{

" Required as some plugins will overwrite
call s:h('MatchParen', s:green, s:none, [s:attrs.underline])
call s:h('Conceal', s:cyan, s:none)

" Neovim uses SpecialKey for escape characters only. Vim uses it for that, plus whitespace.
if has('nvim')
  hi! link SpecialKey SakurineRed
  hi! link LspReferenceText SakurineSelection
  hi! link LspReferenceRead SakurineSelection
  hi! link LspReferenceWrite SakurineSelection
  " Link old 'LspDiagnosticsDefault*' hl groups
  " for backward compatibility with neovim v0.5.x
  hi! link LspDiagnosticsDefaultInformation DiagnosticInfo
  hi! link LspDiagnosticsDefaultHint DiagnosticHint
  hi! link LspDiagnosticsDefaultError DiagnosticError
  hi! link LspDiagnosticsDefaultWarning DiagnosticWarn
  hi! link LspDiagnosticsUnderlineError DiagnosticUnderlineError
  hi! link LspDiagnosticsUnderlineHint DiagnosticUnderlineHint
  hi! link LspDiagnosticsUnderlineInformation DiagnosticUnderlineInfo
  hi! link LspDiagnosticsUnderlineWarning DiagnosticUnderlineWarn
  hi! link LspInlayHint SakurineInlayHint

  hi! link DiagnosticInfo SakurineCyan
  hi! link DiagnosticHint SakurineCyan
  hi! link DiagnosticError SakurineError
  hi! link DiagnosticWarn SakurineOrange
  hi! link DiagnosticUnderlineError SakurineErrorLine
  hi! link DiagnosticUnderlineHint SakurineInfoLine
  hi! link DiagnosticUnderlineInfo SakurineInfoLine
  hi! link DiagnosticUnderlineWarn SakurineWarnLine

  hi! link WinSeparator SakurineWinSeparator
  hi! link NormalFloat Pmenu

  if has('nvim-0.9')
    hi! link  @lsp.type.class SakurineCyan
    hi! link  @lsp.type.decorator SakurineGreen
    hi! link  @lsp.type.enum SakurineCyan
    hi! link  @lsp.type.enumMember SakurinePurple
    hi! link  @lsp.type.function SakurineGreen
    hi! link  @lsp.type.interface SakurineCyan
    hi! link  @lsp.type.macro SakurineCyan
    hi! link  @lsp.type.method SakurineGreen
    hi! link  @lsp.type.namespace SakurineCyan
    hi! link  @lsp.type.parameter SakurineOrangeItalic
    hi! link  @lsp.type.property SakurineOrange
    hi! link  @lsp.type.struct SakurineCyan
    hi! link  @lsp.type.type SakurineCyanItalic
    hi! link  @lsp.type.typeParameter SakurinePink
    hi! link  @lsp.type.variable SakurineFg
  endif
else
  hi! link SpecialKey SakurinePink
endif

hi! link Comment SakurineComment
hi! link Underlined SakurineFgUnderline
hi! link Todo SakurineTodo

hi! link Error SakurineError
hi! link SpellBad SakurineErrorLine
hi! link SpellLocal SakurineWarnLine
hi! link SpellCap SakurineInfoLine
hi! link SpellRare SakurineInfoLine

hi! link Constant SakurinePurple
hi! link String SakurineYellow
hi! link Character SakurinePink
hi! link Number Constant
hi! link Boolean Constant
hi! link Float Constant

hi! link Identifier SakurineFg
hi! link Function SakurineGreen

hi! link Statement SakurinePink
hi! link Conditional SakurinePink
hi! link Repeat SakurinePink
hi! link Label SakurinePink
hi! link Operator SakurinePink
hi! link Keyword SakurinePink
hi! link Exception SakurinePink

hi! link PreProc SakurinePink
hi! link Include SakurinePink
hi! link Define SakurinePink
hi! link Macro SakurinePink
hi! link PreCondit SakurinePink
hi! link StorageClass SakurinePink
hi! link Structure SakurinePink
hi! link Typedef SakurinePink

hi! link Type SakurineCyanItalic

hi! link Delimiter SakurineFg

hi! link Special SakurinePink
hi! link SpecialComment SakurineCyanItalic
hi! link Tag SakurineCyan
hi! link helpHyperTextJump SakurineLink
hi! link helpCommand SakurinePurple
hi! link helpExample SakurineGreen
hi! link helpBacktick Special

" }}}

" Languages: {{{

" CSS: {{{
hi! link cssAttrComma         Delimiter
hi! link cssAttrRegion        SakurinePink
hi! link cssAttributeSelector SakurineGreenItalic
hi! link cssBraces            Delimiter
hi! link cssFunctionComma     Delimiter
hi! link cssNoise             SakurinePink
hi! link cssProp              SakurineCyan
hi! link cssPseudoClass       SakurinePink
hi! link cssPseudoClassId     SakurineGreenItalic
hi! link cssUnitDecorators    SakurinePink
hi! link cssVendor            SakurineGreenItalic
" }}}

" Git Commit: {{{
" The following two are misnomers. Colors are correct.
hi! link diffFile    SakurineGreen
hi! link diffNewFile SakurineRed

hi! link diffAdded   SakurineGreen
hi! link diffLine    SakurineCyanItalic
hi! link diffRemoved SakurineRed
" }}}

" HTML: {{{
hi! link htmlTag         SakurineFg
hi! link htmlArg         SakurineGreenItalic
hi! link htmlTitle       SakurineFg
hi! link htmlH1          SakurineFg
hi! link htmlSpecialChar SakurinePurple
" }}}

" JavaScript: {{{
hi! link javaScriptBraces   Delimiter
hi! link javaScriptNumber   Constant
hi! link javaScriptNull     Constant
hi! link javaScriptFunction Keyword

" pangloss/vim-javascript
hi! link jsArrowFunction           Operator
hi! link jsBuiltins                SakurineCyan
hi! link jsClassDefinition         SakurineCyan
hi! link jsClassMethodType         Keyword
hi! link jsDestructuringAssignment SakurineOrangeItalic
hi! link jsDocParam                SakurineOrangeItalic
hi! link jsDocTags                 Keyword
hi! link jsDocType                 Type
hi! link jsDocTypeBrackets         SakurineCyan
hi! link jsFuncArgOperator         Operator
hi! link jsFuncArgs                SakurineOrangeItalic
hi! link jsFunction                Keyword
hi! link jsNull                    Constant
hi! link jsObjectColon             SakurinePink
hi! link jsSuper                   SakurinePurpleItalic
hi! link jsTemplateBraces          Special
hi! link jsThis                    SakurinePurpleItalic
hi! link jsUndefined               Constant

" maxmellon/vim-jsx-pretty
hi! link jsxTag             Keyword
hi! link jsxTagName         Keyword
hi! link jsxComponentName   Type
hi! link jsxCloseTag        Type
hi! link jsxAttrib          SakurineGreenItalic
hi! link jsxCloseString     Identifier
hi! link jsxOpenPunct       Identifier
" }}}

" JSON: {{{
hi! link jsonKeyword      SakurineCyan
hi! link jsonKeywordMatch SakurinePink
" }}}

" Lua: {{{
hi! link luaFunc  SakurineCyan
hi! link luaTable SakurineFg

" tbastos/vim-lua
hi! link luaBraces       SakurineFg
hi! link luaBuiltIn      Constant
hi! link luaDocTag       Keyword
hi! link luaErrHand      SakurineCyan
hi! link luaFuncArgName  SakurineOrangeItalic
hi! link luaFuncCall     Function
hi! link luaLocal        Keyword
hi! link luaSpecialTable Constant
hi! link luaSpecialValue SakurineCyan
" }}}

" Markdown: {{{
hi! link markdownBlockquote        SakurineCyan
hi! link markdownBold              SakurineOrangeBold
hi! link markdownBoldItalic        SakurineOrangeBoldItalic
hi! link markdownCodeBlock         SakurineGreen
hi! link markdownCode              SakurineGreen
hi! link markdownCodeDelimiter     SakurineGreen
hi! link markdownH1                SakurinePurpleBold
hi! link markdownH2                markdownH1
hi! link markdownH3                markdownH1
hi! link markdownH4                markdownH1
call s:h('markdownH5', s:purple, s:subtle, [s:attrs.bold])
call s:h('markdownH6', s:purple, s:none, [s:attrs.bold])
hi! link markdownHeadingDelimiter  markdownH1

" Plugin specific overrides for Headlines
hi! link Headline5          markdownH1
hi! link Headline5Bg        CursorLine
hi! link RenderMarkdownH5   markdownH1
hi! link RenderMarkdownH5Bg CursorLine
hi! link Headline6          markdownH1
hi! link Headline6Bg        SakurineBg
hi! link RenderMarkdownH6   markdownH1
hi! link RenderMarkdownH6Bg SakurineBg
hi! link markdownHeadingRule       markdownH1
hi! link markdownItalic            SakurineYellowItalic
hi! link markdownLinkText          SakurinePink
hi! link markdownListMarker        SakurineCyan
hi! link markdownOrderedListMarker SakurineCyan
hi! link markdownRule              SakurineComment
hi! link markdownUrl               SakurineLink

" plasticboy/vim-markdown
hi! link htmlBold       SakurineOrangeBold
hi! link htmlBoldItalic SakurineOrangeBoldItalic
hi! link htmlH1         SakurinePurpleBold
hi! link htmlH2         htmlH1
hi! link htmlH3         htmlH1
hi! link htmlH4         htmlH1
call s:h('htmlH5', s:purple, s:subtle, [s:attrs.bold])
call s:h('htmlH6', s:purple, s:none, [s:attrs.bold])
hi! link htmlItalic     SakurineYellowItalic
hi! link mkdBlockquote  SakurineYellowItalic
hi! link mkdBold        SakurineOrangeBold
hi! link mkdBoldItalic  SakurineOrangeBoldItalic
hi! link mkdCode        SakurineGreen
hi! link mkdCodeEnd     SakurineGreen
hi! link mkdCodeStart   SakurineGreen
hi! link mkdHeading     SakurinePurpleBold
hi! link mkdInlineUrl   SakurineLink
hi! link mkdItalic      SakurineYellowItalic
hi! link mkdLink        SakurinePink
hi! link mkdListItem    SakurineCyan
hi! link mkdRule        SakurineComment
hi! link mkdUrl         SakurineLink
" }}}

" OCaml: {{{
hi! link ocamlModule  Type
hi! link ocamlModPath Normal
hi! link ocamlLabel   SakurineOrangeItalic
" }}}

" Perl: {{{
" Regex
hi! link perlMatchStartEnd       SakurineRed

" Builtin functions
hi! link perlOperator            SakurineCyan
hi! link perlStatementFiledesc   SakurineCyan
hi! link perlStatementFiles      SakurineCyan
hi! link perlStatementFlow       SakurineCyan
hi! link perlStatementHash       SakurineCyan
hi! link perlStatementIOfunc     SakurineCyan
hi! link perlStatementIPC        SakurineCyan
hi! link perlStatementList       SakurineCyan
hi! link perlStatementMisc       SakurineCyan
hi! link perlStatementNetwork    SakurineCyan
hi! link perlStatementNumeric    SakurineCyan
hi! link perlStatementProc       SakurineCyan
hi! link perlStatementPword      SakurineCyan
hi! link perlStatementRegexp     SakurineCyan
hi! link perlStatementScalar     SakurineCyan
hi! link perlStatementSocket     SakurineCyan
hi! link perlStatementTime       SakurineCyan
hi! link perlStatementVector     SakurineCyan

" Highlighting for quoting constructs, tied to existing option in vim-perl
if get(g:, 'perl_string_as_statement', 0)
  hi! link perlStringStartEnd SakurineRed
endif

" Signatures
hi! link perlSignature           SakurineOrangeItalic
hi! link perlSubPrototype        SakurineOrangeItalic

" Hash keys
hi! link perlVarSimpleMemberName SakurinePurple
" }}}

" PHP: {{{
hi! link phpClass           Type
hi! link phpClasses         Type
hi! link phpDocTags         SakurineCyanItalic
hi! link phpFunction        Function
hi! link phpParent          Normal
hi! link phpSpecialFunction SakurineCyan
" }}}

" PlantUML: {{{
hi! link plantumlClassPrivate              SpecialKey
hi! link plantumlClassProtected            SakurineOrange
hi! link plantumlClassPublic               Function
hi! link plantumlColonLine                 String
hi! link plantumlDirectedOrVerticalArrowLR Constant
hi! link plantumlDirectedOrVerticalArrowRL Constant
hi! link plantumlHorizontalArrow           Constant
hi! link plantumlSkinParamKeyword          SakurineCyan
hi! link plantumlTypeKeyword               Keyword
" }}}

" PureScript: {{{
hi! link purescriptModule Type
hi! link purescriptImport SakurineCyan
hi! link purescriptImportAs SakurineCyan
hi! link purescriptOperator Operator
hi! link purescriptBacktick Operator
" }}}

" Python: {{{
hi! link pythonBuiltinObj    Type
hi! link pythonBuiltinObject Type
hi! link pythonBuiltinType   Type
hi! link pythonClassVar      SakurinePurpleItalic
hi! link pythonExClass       Type
hi! link pythonNone          Type
hi! link pythonRun           Comment
" }}}

" reStructuredText: {{{
hi! link rstComment                             Comment
hi! link rstTransition                          Comment
hi! link rstCodeBlock                           SakurineGreen
hi! link rstInlineLiteral                       SakurineGreen
hi! link rstLiteralBlock                        SakurineGreen
hi! link rstQuotedLiteralBlock                  SakurineGreen
hi! link rstStandaloneHyperlink                 SakurineLink
hi! link rstStrongEmphasis                      SakurineOrangeBold
hi! link rstSections                            SakurinePurpleBold
hi! link rstEmphasis                            SakurineYellowItalic
hi! link rstDirective                           Keyword
hi! link rstSubstitutionDefinition              Keyword
hi! link rstCitation                            String
hi! link rstExDirective                         String
hi! link rstFootnote                            String
hi! link rstCitationReference                   Tag
hi! link rstFootnoteReference                   Tag
hi! link rstHyperLinkReference                  Tag
hi! link rstHyperlinkTarget                     Tag
hi! link rstInlineInternalTargets               Tag
hi! link rstInterpretedTextOrHyperlinkReference Tag
hi! link rstTodo                                Todo
" }}}

" Ruby: {{{
if ! exists('g:ruby_operators')
    let g:ruby_operators=1
endif

hi! link rubyBlockArgument          SakurineOrangeItalic
hi! link rubyBlockParameter         SakurineOrangeItalic
hi! link rubyCurlyBlock             SakurinePink
hi! link rubyGlobalVariable         SakurinePurple
hi! link rubyInstanceVariable       SakurinePurpleItalic
hi! link rubyInterpolationDelimiter SakurinePink
hi! link rubyRegexpDelimiter        SakurineRed
hi! link rubyStringDelimiter        SakurineYellow
" }}}

" Rust: {{{
hi! link rustCommentLineDoc Comment
" }}}

" Sass: {{{
hi! link sassClass                  cssClassName
hi! link sassClassChar              cssClassNameDot
hi! link sassId                     cssIdentifier
hi! link sassIdChar                 cssIdentifier
hi! link sassInterpolationDelimiter SakurinePink
hi! link sassMixinName              Function
hi! link sassProperty               cssProp
hi! link sassVariableAssignment     Operator
" }}}

" Shell: {{{
hi! link shCommandSub NONE
hi! link shEscape     SakurineRed
hi! link shParen      NONE
hi! link shParenError NONE
" }}}

" Tex: {{{
hi! link texBeginEndName  SakurineOrangeItalic
hi! link texBoldItalStyle SakurineOrangeBoldItalic
hi! link texBoldStyle     SakurineOrangeBold
hi! link texInputFile     SakurineOrangeItalic
hi! link texItalStyle     SakurineYellowItalic
hi! link texLigature      SakurinePurple
hi! link texMath          SakurinePurple
hi! link texMathMatcher   SakurinePurple
hi! link texMathSymbol    SakurinePurple
hi! link texSpecialChar   SakurinePurple
hi! link texSubscripts    SakurinePurple
hi! link texTitle         SakurineFgBold
" }}}

" Typescript: {{{
hi! link typescriptAliasDeclaration       Type
hi! link typescriptArrayMethod            Function
hi! link typescriptArrowFunc              Operator
hi! link typescriptArrowFuncArg           SakurineOrangeItalic
hi! link typescriptAssign                 Operator
hi! link typescriptBOMWindowProp          Constant
hi! link typescriptBinaryOp               Operator
hi! link typescriptBraces                 Delimiter
hi! link typescriptCall                   typescriptArrowFuncArg
hi! link typescriptClassHeritage          Type
hi! link typescriptClassName              Type
hi! link typescriptDateMethod             SakurineCyan
hi! link typescriptDateStaticMethod       Function
hi! link typescriptDecorator              SakurineGreenItalic
hi! link typescriptDefaultParam           Operator
hi! link typescriptES6SetMethod           SakurineCyan
hi! link typescriptEndColons              Delimiter
hi! link typescriptEnum                   Type
hi! link typescriptEnumKeyword            Keyword
hi! link typescriptFuncComma              Delimiter
hi! link typescriptFuncKeyword            Keyword
hi! link typescriptFuncType               SakurineOrangeItalic
hi! link typescriptFuncTypeArrow          Operator
hi! link typescriptGlobal                 Type
hi! link typescriptGlobalMethod           SakurineCyan
hi! link typescriptGlobalObjects          Type
hi! link typescriptIdentifier             SakurinePurpleItalic
hi! link typescriptInterfaceHeritage      Type
hi! link typescriptInterfaceName          Type
hi! link typescriptInterpolationDelimiter Keyword
hi! link typescriptKeywordOp              Keyword
hi! link typescriptLogicSymbols           Operator
hi! link typescriptMember                 Identifier
hi! link typescriptMemberOptionality      Special
hi! link typescriptObjectColon            Special
hi! link typescriptObjectLabel            Identifier
hi! link typescriptObjectSpread           Operator
hi! link typescriptOperator               Operator
hi! link typescriptParamImpl              SakurineOrangeItalic
hi! link typescriptParens                 Delimiter
hi! link typescriptPredefinedType         Type
hi! link typescriptRestOrSpread           Operator
hi! link typescriptTernaryOp              Operator
hi! link typescriptTypeAnnotation         Special
hi! link typescriptTypeCast               Operator
hi! link typescriptTypeParameter          SakurineOrangeItalic
hi! link typescriptTypeReference          Type
hi! link typescriptUnaryOp                Operator
hi! link typescriptVariable               Keyword

hi! link tsxAttrib           SakurineGreenItalic
hi! link tsxEqual            Operator
hi! link tsxIntrinsicTagName Keyword
hi! link tsxTagName          Type
" }}}

" Vim: {{{
hi! link vimAutoCmdSfxList     Type
hi! link vimAutoEventList      Type
hi! link vimEnvVar             Constant
hi! link vimFunction           Function
hi! link vimHiBang             Keyword
hi! link vimOption             Type
hi! link vimSetMod             Keyword
hi! link vimSetSep             Delimiter
hi! link vimUserAttrbCmpltFunc Function
hi! link vimUserFunc           Function
" }}}

" XML: {{{
hi! link xmlAttrib  SakurineGreenItalic
hi! link xmlEqual   Operator
hi! link xmlTag     Delimiter
hi! link xmlTagName Statement

" Fixes missing highlight over end tags
syn region xmlTagName
	\ matchgroup=xmlTag start=+</[^ /!?<>"']\@=+
	\ matchgroup=xmlTag end=+>+
" }}}

" YAML: {{{
hi! link yamlAlias           SakurineGreenItalicUnderline
hi! link yamlAnchor          SakurinePinkItalic
hi! link yamlBlockMappingKey SakurineCyan
hi! link yamlFlowCollection  SakurinePink
hi! link yamlFlowIndicator   Delimiter
hi! link yamlNodeTag         SakurinePink
hi! link yamlPlainScalar     SakurineYellow
" }}}

" }}}

" Plugins: {{{

" junegunn/fzf {{{
if ! exists('g:fzf_colors')
  let g:fzf_colors = {
    \ 'fg':      ['fg', 'Normal'],
    \ 'bg':      ['bg', 'Normal'],
    \ 'hl':      ['fg', 'Search'],
    \ 'fg+':     ['fg', 'Normal'],
    \ 'bg+':     ['bg', 'Normal'],
    \ 'hl+':     ['fg', 'SakurineOrange'],
    \ 'info':    ['fg', 'SakurinePurple'],
    \ 'border':  ['fg', 'Ignore'],
    \ 'prompt':  ['fg', 'SakurineGreen'],
    \ 'pointer': ['fg', 'Exception'],
    \ 'marker':  ['fg', 'Keyword'],
    \ 'spinner': ['fg', 'Label'],
    \ 'header':  ['fg', 'Comment'],
    \}
endif
" }}}

" dense-analysis/ale {{{
hi! link ALEError              SakurineErrorLine
hi! link ALEWarning            SakurineWarnLine
hi! link ALEInfo               SakurineInfoLine

hi! link ALEErrorSign          SakurineRed
hi! link ALEWarningSign        SakurineOrange
hi! link ALEInfoSign           SakurineCyan

hi! link ALEVirtualTextError   Comment
hi! link ALEVirtualTextWarning Comment
" }}}

" ctrlpvim/ctrlp.vim: {{{
hi! link CtrlPMatch     IncSearch
hi! link CtrlPBufferHid Normal
" }}}

" airblade/vim-gitgutter {{{
hi! link GitGutterAdd    DiffAdd
hi! link GitGutterChange DiffChange
hi! link GitGutterDelete DiffDelete
" }}}

" Neovim-only plugins {{{
if has('nvim')

  " nvim-treesitter/nvim-treesitter: {{{
  " The nvim-treesitter library defines many global highlight groups that are
  " linked to the regular vim syntax highlight groups. We only need to redefine
  " those highlight groups when the defaults do not match the sakurine
  " specification.
  " https://github.com/nvim-treesitter/nvim-treesitter/blob/master/plugin/nvim-treesitter.vim

  " deprecated TS* highlight groups
  " see https://github.com/nvim-treesitter/nvim-treesitter/pull/3656
  " # Misc
  hi! link TSPunctSpecial Special
  " # Constants
  hi! link TSConstMacro Macro
  hi! link TSStringEscape Character
  hi! link TSSymbol SakurinePurple
  hi! link TSAnnotation SakurineYellow
  hi! link TSAttribute SakurineGreenItalic
  " # Functions
  hi! link TSFuncBuiltin SakurineCyan
  hi! link TSFuncMacro Function
  hi! link TSParameter SakurineOrangeItalic
  hi! link TSParameterReference SakurineOrange
  hi! link TSField SakurineOrange
  hi! link TSConstructor SakurineCyan
  " # Keywords
  hi! link TSLabel SakurinePurpleItalic
  " # Variable
  hi! link TSVariableBuiltin SakurinePurpleItalic
  " # Text
  hi! link TSStrong SakurineFgBold
  hi! link TSEmphasis SakurineFg
  hi! link TSUnderline Underlined
  hi! link TSTitle SakurineYellow
  hi! link TSLiteral SakurineYellow
  hi! link TSURI SakurineYellow
  " HTML and JSX tag attributes. By default, this group is linked to TSProperty,
  " which in turn links to Identifer (white).
  hi! link TSTagAttribute SakurineGreenItalic

  if has('nvim-0.8.1')
    " # Markdown Headings
    hi! link @markup.heading.1.markdown SakurinePurpleBold
    hi! link @markup.heading.2.markdown SakurinePurpleBold
    hi! link @markup.heading.3.markdown SakurinePurpleBold
    hi! link @markup.heading.4.markdown SakurinePurpleBold
    hi! link @markup.heading.5.markdown SakurinePurpleBold
    hi! link @markup.heading.6.markdown SakurinePurpleBold
    
    " # Fallback for other treesitter versions/grammars
    hi! link @text.title.1.markdown SakurinePurpleBold
    hi! link @text.title.2.markdown SakurinePurpleBold
    hi! link @text.title.3.markdown SakurinePurpleBold
    hi! link @text.title.4.markdown SakurinePurpleBold
    hi! link @text.title.5.markdown SakurinePurpleBold
    hi! link @text.title.6.markdown SakurinePurpleBold
    
    hi! link @markup.heading.1 SakurinePurpleBold
    hi! link @markup.heading.2 SakurinePurpleBold
    hi! link @markup.heading.3 SakurinePurpleBold
    hi! link @markup.heading.4 SakurinePurpleBold
    hi! link @markup.heading.5 SakurinePurpleBold
    hi! link @markup.heading.6 SakurinePurpleBold

    " # Misc
    hi! link @punctuation.delimiter Delimiter
    hi! link @punctuation.bracket SakurineFg
    hi! link @punctuation.special Special
    hi! link @punctuation Delimiter
    " # Constants
    hi! link @constant Constant
    hi! link @constant.builtin Constant
    hi! link @constant.macro Macro
    hi! link @string.regex @string.special
    hi! link @string.escape @string.special
    hi! link @string String
    hi! link @string.regexp @string.special
    hi! link @string.special SpecialChar
    hi! link @string.special.symbol SakurinePurple
    hi! link @string.special.url Underlined
    hi! link @symbol SakurinePurple
    hi! link @annotation SakurineYellow
    hi! link @attribute SakurineGreenItalic
    hi! link @namespace Structure
    hi! link @module Structure
    hi! link @module.builtin Special
    " # Functions
    hi! link @function.builtin SakurineCyan
    hi! link @funcion.macro Function
    hi! link @function Function
    hi! link @parameter SakurineOrangeItalic
    hi! link @parameter.reference SakurineOrange
    hi! link @field SakurineOrange
    hi! link @property SakurineFg
    hi! link @constructor SakurineCyan
    " # Keywords
    hi! link @label SakurinePurpleItalic
    hi! link @keyword.function SakurinePink
    hi! link @keyword.operator Operator
    hi! link @keyword Keyword
    hi! link @exception SakurinePurple
    hi! link @operator Operator
    " # Types
    hi! link @type Type
    hi! link @type.builtin Special
    hi! link @character Character
    hi! link @character.special SpecialChar
    hi! link @boolean Boolean
    hi! link @number Number
    hi! link @number.float Float
    " # Variable
    hi! link @variable SakurineFg
    hi! link @variable.builtin SakurinePurpleItalic
    hi! link @variable.parameter SakurineOrangeItalic
    hi! link @variable.member  SakurineOrange
    " # Text
    hi! link @text SakurineFg
    hi! link @text.strong SakurineFgBold
    hi! link @text.emphasis SakurineFg
    hi! link @text.underline Underlined
    hi! link @text.title SakurineYellow
    hi! link @text.literal SakurineYellow
    hi! link @text.uri SakurineYellow
    hi! link @text.diff.add DiffAdd
    hi! link @text.diff.delete DiffDelete

    hi! link @markup.strong SakurineFgBold
    hi! link @markup.italic SakurineFgItalic
    hi! link @markup.strikethrough SakurineFgStrikethrough
    hi! link @markup.underline Underlined

    hi! link @markup Special
    hi! link @markup.heading SakurineYellow
    hi! link @markup.link Underlined
    hi! link @markup.link.uri SakurineYellow
    hi! link @markup.link.label SpecialChar
    hi! link @markup.raw SakurineYellow
    hi! link @markup.list Special

    hi! link @comment Comment
    hi! link @comment.error DiagnosticError
    hi! link @comment.warning DiagnosticWarn
    hi! link @comment.note DiagnosticInfo
    hi! link @comment.todo Todo

    hi! link @diff.plus Added
    hi! link @diff.minus Removed
    hi! link @diff.delta Changed

    " # Tags
    hi! link @tag SakurineCyan
    hi! link @tag.delimiter SakurineFg
    " HTML and JSX tag attributes. By default, this group is linked to TSProperty,
    " which in turn links to Identifer (white).
    hi! link @tag.attribute SakurineGreenItalic
  endif
  " }}}

  " hrsh7th/nvim-cmp {{{
  hi! link CmpItemAbbrDeprecated SakurineError

  hi! link CmpItemAbbrMatch SakurineCyan
  hi! link CmpItemAbbrMatchFuzzy SakurineCyan

  hi! link CmpItemKindText SakurineFg
  hi! link CmpItemKindMethod Function
  hi! link CmpItemKindFunction Function
  hi! link CmpItemKindConstructor SakurineCyan
  hi! link CmpItemKindField SakurineOrange
  hi! link CmpItemKindVariable SakurinePurpleItalic
  hi! link CmpItemKindClass SakurineCyan
  hi! link CmpItemKindInterface SakurineCyan
  hi! link CmpItemKindModule SakurineYellow
  hi! link CmpItemKindProperty SakurinePink
  hi! link CmpItemKindUnit SakurineFg
  hi! link CmpItemKindValue SakurineYellow
  hi! link CmpItemKindEnum SakurinePink
  hi! link CmpItemKindKeyword SakurinePink
  hi! link CmpItemKindSnippet SakurineFg
  hi! link CmpItemKindColor SakurineYellow
  hi! link CmpItemKindFile SakurineYellow
  hi! link CmpItemKindReference SakurineOrange
  hi! link CmpItemKindFolder SakurineYellow
  hi! link CmpItemKindEnumMember SakurinePurple
  hi! link CmpItemKindConstant SakurinePurple
  hi! link CmpItemKindStruct SakurinePink
  hi! link CmpItemKindEvent SakurineFg
  hi! link CmpItemKindOperator SakurinePink
  hi! link CmpItemKindTypeParameter SakurineCyan

  hi! link CmpItemMenu Comment
  " }}}

  " lewis6991/gitsigns.nvim {{{
  hi! link GitSignsAdd      DiffAdd
  hi! link GitSignsAddLn    DiffAdd
  hi! link GitSignsAddNr    DiffAdd
  hi! link GitSignsChange   DiffChange
  hi! link GitSignsChangeLn DiffChange
  hi! link GitSignsChangeNr DiffChange

  hi! link GitSignsDelete   SakurineRed
  hi! link GitSignsDeleteLn SakurineRed
  hi! link GitSignsDeleteNr SakurineRed
  " }}}

  " Saghen/blink.cmp {{{
  hi! link BlinkCmpKindText SakurineFg
  hi! link BlinkCmpKindMethod Function
  hi! link BlinkCmpKindFunction Function
  hi! link BlinkCmpKindConstructor SakurineCyan
  hi! link BlinkCmpKindField SakurineOrange
  hi! link BlinkCmpKindVariable SakurinePurpleItalic
  hi! link BlinkCmpKindClass SakurineCyan
  hi! link BlinkCmpKindInterface SakurineCyan
  hi! link BlinkCmpKindModule SakurineYellow
  hi! link BlinkCmpKindProperty SakurinePink
  hi! link BlinkCmpKindUnit SakurineFg
  hi! link BlinkCmpKindValue SakurineYellow
  hi! link BlinkCmpKindEnum SakurinePink
  hi! link BlinkCmpKindKeyword SakurinePink
  hi! link BlinkCmpKindSnippet SakurineFg
  hi! link BlinkCmpKindColor SakurineYellow
  hi! link BlinkCmpKindFile SakurineYellow
  hi! link BlinkCmpKindReference SakurineOrange
  hi! link BlinkCmpKindFolder SakurineYellow
  hi! link BlinkCmpKindEnumMember SakurinePurple
  hi! link BlinkCmpKindConstant SakurinePurple
  hi! link BlinkCmpKindStruct SakurinePink
  hi! link BlinkCmpKindEvent SakurineFg
  hi! link BlinkCmpKindOperator SakurinePink
  hi! link BlinkCmpKindTypeParameter SakurineCyan
  " }}}

endif
" }}}

" }}}

" vim: fdm=marker ts=2 sts=2 sw=2 fdl=0 et:
