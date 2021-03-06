/* XLang
 * -- A parser framework for language modeling
 * Copyright (C) 2011 onlyuser <mailto:onlyuser@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

%option outfile="lex.XLang.c"

%{

#include "XLang.h"
#include "XLangLexerIDWrapper.h" // ID_XXX (yacc generated)
#include <string.h> // memcpy
#include <stdlib.h> // atoi
#include <algorithm> // std::min

// When in the lexer you have to access parm through the extra data.
#define PARM yyget_extra(yyscanner)->scanner_context()

// We want to read from a the buffer in parm so we have to redefine the
// YY_INPUT macro (see section 10 of the flex manual 'The generated scanner')
#define YY_INPUT(buf, result, max_size) \
    do { \
        if(PARM.m_pos >= PARM.m_length || (max_size)<1) { \
            (result) = YY_NULL; \
            break; \
        } else { \
            if('\n' == PARM.m_buf[PARM.m_pos]) { \
                PARM.m_line++; \
                PARM.m_column = 1; \
            } else \
                PARM.m_column++; \
            (buf)[0] = PARM.m_buf[PARM.m_pos]; \
            PARM.m_pos++; \
            (result) = 1; \
        } \
    } while(0)

#define LOC           begin_token(yyscanner, yyleng)
#define PUSH_STATE(x) yy_push_state(x, yyscanner)
#define POP_STATE     yy_pop_state(yyscanner)
#define LVAL          (*yylval)
#define TREE_CONTEXT  yyget_extra(yyscanner)->tree_context()

void begin_token(yyscan_t yyscanner, size_t length);

%}

%option noyywrap nounput noyy_top_state
%option reentrant bison-bridge bison-locations
%option stack
%x ST_COMMENT_BLOCK ST_COMMENT_LINE

ws        [ \t\n]+
any       .|[\n]
lit_char  [,()+\-*/=]
digit     [0-9]
alpha     [a-zA-Z]
id        {alpha}|[_]
lit_ident {id}+({digit}|{id})*
lit_int   {digit}+
lit_float {digit}*[.]{digit}+

%%

{ws}        {LOC;}

 /*==========================================================================*/
 /* COMMENTS */

"/*"        {
                PUSH_STATE(ST_COMMENT_BLOCK);
            }
<ST_COMMENT_BLOCK>"*/" {
                POP_STATE;
            }
<ST_COMMENT_BLOCK>{any} ;

"//"        {
                PUSH_STATE(ST_COMMENT_LINE);
            }
<ST_COMMENT_LINE>"\n" {
                POP_STATE;
            }
<ST_COMMENT_LINE>. ;

 /*==========================================================================*/
 /* LITERALS */

{lit_ident} {LOC;
                LVAL.ident_value = TREE_CONTEXT.alloc_unique_string(yytext);
                return ID_IDENT;
            }

{lit_int}   {LOC;
                LVAL.int_value = atoi(yytext);
                return ID_INT;
            }

{lit_float} {LOC;
                LVAL.float_value = atof(yytext);
                return ID_FLOAT;
            }

{lit_char}  {LOC;
                return *yytext;
            }

 /*==========================================================================*/
 /* OTHER */

.           {LOC;
                yyerror("unknown character");
                YY_FLUSH_BUFFER;
                BEGIN INITIAL;
            }

%%

void begin_token(yyscan_t yyscanner, size_t length)
{
    YYLTYPE* loc = yyget_lloc(yyscanner);
    loc->first_line    = PARM.m_line;
    loc->first_column  = PARM.m_prev_column;
    loc->last_line     = PARM.m_line;
    loc->last_column   = PARM.m_prev_column+length-1;
    PARM.m_prev_column = PARM.m_column;
    PARM.m_prev_column--; // compensate for 1-char over-read
}
