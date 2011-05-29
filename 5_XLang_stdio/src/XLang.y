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
#include "XLangView.h" // View
#include "XLangModel.h" // mvc::Model
#include <stdio.h> // size_t
#include <stdarg.h> // va_start
#include <string.h> // strlen
#include <string> // std::string
#include <sstream> // std::stringstream
#include <iostream> // std::cout

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
      program { parse_context()->root() = $1; YYACCEPT; }
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

node::NodeBase* make_ast(Allocator &alloc)
{
    ParseContext* &pc = parse_context();
    pc = new (alloc, __FILE__, __LINE__) ParseContext(alloc);
    int error = _XLANG_parse(); // parser entry point
    return ((0 == error) && errors().str().empty()) ? (node::NodeBase*) pc->root() : NULL;
}

int main(int argc, char** argv)
{
    if (1 != argc)
    {
        std::cout << "ERROR: requires stdin arguments" << std::endl;
        return 1;
    }
    Allocator alloc(__FILE__);
    node::NodeBase* node = make_ast(alloc);
    if (NULL == node)
    {
        std::cout << argv[1] << std::endl << errors().str().c_str() << std::endl;
        return 1;
    }
    std::cout << "PARSE: ";
    mvc::View::print_lisp(node); std::cout << std::endl;
    std::cout << "GRAPH:";
    mvc::View::print_graph(node);
    std::cout << std::endl;
    alloc.dump();
    return 0;
}