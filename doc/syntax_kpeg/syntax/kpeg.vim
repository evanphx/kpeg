" Vim syntax file
" Language:   kpeg
" Version:      $Revision$

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case match

" Misc syntax.
syn match   kpegOperator /[|*?+!\[\]]/
syn match   kpegAssign "="
syn match   kpegCapture /[<>]/
syn match   kpegParen /[()]/

syn match   kpegIdentifier /-|([a-zA-Z][-a-zA-Z0-9]*)/
syn match   kpegComment /#.*$/
syn region  kpegString start="\"" end="\"" skip="\\\\\|\\\""
syn region  kpegRegexp start=/\// skip=/\\\// end=/\//

syntax include @Ruby syntax/ruby.vim

syn region  kpegCode   matchgroup=kpegCurly start=/{/ end=/}/ contains=@Ruby

syn match   kpegLabel /:[a-zA-Z][-a-zA-Z0-9]*/

if version >= 508 || !exists("did_c_syn_inits")
  if version < 508
    let did_c_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink kpegRegexp Special
  HiLink kpegNumber Number
  HiLink kpegComment Comment
  HiLink kpegString String
  HiLink kpegLabel Type
  HiLink kpegOperator Operator
  HiLink kpegAssign Define
  HiLink kpegCapture Keyword
  HiLink kpegFloat Float
  HiLink kpegIdentifier Identifier

  HiLink kpegParen Delimiter
  HiLink kpegCurly Delimiter

  delcommand HiLink
endif

let b:current_syntax = "kpeg"
