// Variations of a Flex-Bison parser
// -- based on "A COMPACT GUIDE TO LEX & YACC" by Tom Niemann
// Copyright (C) 2011 Jerry Chen <mailto:onlyuser@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.

//%output="XLang.tab.c"
%name-prefix="_XLANG_"

%{

#include "XLangType.h" // char*
#include "XLang.h" // node::NodeBase (owner)
#include "XLang.tab.h" // ID_XXX (generated code)
#include "XLangAlloc.h" // Allocator
#include "XLangView.h" // mvc::View
#include "XLangModel.h" // mvc::Model
#include <stdio.h> // fread
#include <stdarg.h> // va_start
#include <string.h> // memset
#include <ctype.h> // isalpha
#include <stdlib.h> // atoi
#include <string> // std::string
#include <sstream> // std::stringstream
#include <iostream> // std::cout

#define SIZE_BUFMALL 160

// report error
void _XLANG_error(const char* s)
{
    errors() << s;
}

// get resource
std::stringstream &errors()
{
    static std::stringstream _errors;
    return _errors;
}
const char* sym_name(uint32 sym_id)
{
    static const char* _sym_name[ID_COUNT - ID_BASE - 1] = {
        "ID_FLOAT",
        "ID_IDENT"
        };
    switch (sym_id)
    {
        case '+': return "+";
        case '-': return "-";
        case '*': return "*";
        case '/': return "/";
        case '=': return "=";
        case ',': return ",";
    }
    return _sym_name[sym_id - ID_BASE - 1];
}
ParseContext* &parse_context()
{
    static ParseContext* pc = NULL;
    return pc;
}

// When in the lexer you have to access parm through the extra data.
//
#define PARM parse_context()->scan_context()

// We want to read from a the buffer in parm so we have to redefine the
// YY_INPUT macro (see section 10 of the flex manual 'The generated scanner')
//
#define YY_INPUT(buffer, res, max_size)                        \
    do {                                                       \
        if (PARM.m_pos >= PARM.m_length)                       \
            (res) = 0;                                         \
        else {                                                 \
            (res) = PARM.m_length - PARM.m_pos;                \
            (res) > (int) (max_size) ? (res) = (max_size) : 0; \
            fread((buffer), sizeof(char), (res), PARM.m_file); \
            PARM.m_pos += (res);                               \
        }                                                      \
    } while (0)

int _XLANG_lex()
{
    char yytext[SIZE_BUFMALL];
    memset(yytext, 0, sizeof(yytext));
    char* prev_char = NULL;
    int bytes_read = 0;
    int start_pos = PARM.m_pos;
    YY_INPUT(yytext, bytes_read, 1);
    if (0 == bytes_read)
        return -1;
    if (isalpha(*yytext) || '_' == *yytext)
    {
        do
        {
            prev_char = &yytext[PARM.m_pos - start_pos];
            YY_INPUT(prev_char, bytes_read, 1);
        } while (bytes_read != 0 && (isalpha(*prev_char) || '_' == *prev_char));
        while (bytes_read != 0 && (isdigit(*prev_char) || isalpha(*prev_char) || '_' == *prev_char))
        {
            prev_char = &yytext[PARM.m_pos - start_pos];
            YY_INPUT(prev_char, bytes_read, 1);
        }
        if (bytes_read != 0)
        {
            fseek(PARM.m_file, -1, SEEK_CUR); PARM.m_pos--;
            yytext[PARM.m_pos - start_pos] = 0;
        }
        _XLANG_lval.name = parse_context()->alloc_unique_string(yytext);
        return ID_IDENT;
    }
    else if (isdigit(*yytext))
    {
        do
        {
            prev_char = &yytext[PARM.m_pos - start_pos];
            YY_INPUT(prev_char, bytes_read, 1);
        } while (bytes_read != 0 && isdigit(*prev_char));
        if (bytes_read != 0)
        {
            fseek(PARM.m_file, -1, SEEK_CUR); PARM.m_pos--;
            yytext[PARM.m_pos - start_pos] = 0;
        }
        _XLANG_lval._float = atof(yytext);
        return ID_FLOAT;
    }
    else
    {
        switch (*yytext)
        {
            case ',':
            case '(': case ')':
            case '+': case '-':
            case '*': case '/':
            case '=':
            case '\n':
                return *yytext;
            default:
                _XLANG_error("Unknown character");
        }
    }
    return -1;
}

%}

// type of yylval to be set by scanner actions
// implemented as %union in non-reentrant mode
//
%union
{
    float32 _float; // float value
    const std::string* name; // symbol table index
    node::NodeBase* node; // node pointer
}

// show detailed parse errors
%error-verbose

%nonassoc ID_BASE

%token<_float> ID_FLOAT
%token<name> ID_IDENT
%type<node> program statement expression

%left '+' '-'
%left '*' '/'

%nonassoc ID_COUNT

%%

root:
      program { parse_context()->root() = $1; }
    | error   { yyclearin; /* yyerrok; YYABORT; */ }
    ;

program:
      statement             { $$ = $1; }
    | statement ',' program { $$ = mvc::Model::make_inner(parse_context(), ',', 2, $1, $3); }
    ;

statement:
      expression              { $$ = $1; }
    | ID_IDENT '=' expression { $$ = mvc::Model::make_inner(parse_context(), '=', 2,
                                        mvc::Model::make_ident(parse_context(), ID_IDENT, $1), $3); }
    ;

expression:
      ID_FLOAT                  { $$ = mvc::Model::make_float(parse_context(), ID_FLOAT, $1); }
    | ID_IDENT                  { $$ = mvc::Model::make_ident(parse_context(), ID_IDENT, $1); }
    | expression '+' expression { $$ = mvc::Model::make_inner(parse_context(), '+', 2, $1, $3); }
    | expression '-' expression { $$ = mvc::Model::make_inner(parse_context(), '-', 2, $1, $3); }
    | expression '*' expression { $$ = mvc::Model::make_inner(parse_context(), '*', 2, $1, $3); }
    | expression '/' expression { $$ = mvc::Model::make_inner(parse_context(), '/', 2, $1, $3); }
    | '(' expression ')'        { $$ = $2; }
    ;

%%

ScanContext::ScanContext(FILE* file)
    : m_file(file), m_pos(0)
{
    fseek(file, 0, SEEK_END);
    m_length = ftell(file);
    rewind(file);
}

node::NodeBase* make_ast(Allocator &alloc, FILE* file)
{
    parse_context() = new (alloc, __FILE__, __LINE__) ParseContext(alloc, file);
    int error = _XLANG_parse(); // parser entry point
    return ((0 == error) && errors().str().empty()) ? (node::NodeBase*) parse_context()->root() : NULL;
}

int main(int argc, char** argv)
{
    if (2 > argc)
    {
        std::cout << "ERROR: requires 1 or more filename arguments" << std::endl;
        return 1;
    }
    Allocator alloc(__FILE__);
    int i;
    for (i = 1; i < argc; i++)
    {
        FILE* file = fopen(argv[i], "rb");
        if (NULL == file)
            break;
        node::NodeBase* node = make_ast(alloc, file);
        fclose(file);
        if (NULL == node)
        {
            std::cout << argv[1] << std::endl << errors().str().c_str() << std::endl;
            continue;
        }
        std::cout << "INPUT: " << argv[i] << std::endl;
        std::cout << "PARSE: ";
        mvc::View::print_lisp(node); std::cout << std::endl;
        std::cout << "GRAPH:";
        mvc::View::print_graph(node);
        std::cout << std::endl;
    }
    alloc.dump();
    return 0;
}
