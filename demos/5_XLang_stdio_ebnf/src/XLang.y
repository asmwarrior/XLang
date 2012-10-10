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

#include "XLang.h" // node::NodeIdentIFace
#include "XLang.tab.h" // ID_XXX (yacc generated)
#include "XLangAlloc.h" // Allocator
#include "mvc/XLangMVCView.h" // mvc::MVCView
#include "mvc/XLangMVCModel.h" // mvc::MVCModel
#include "XLangTreeContext.h" // TreeContext
#include "XLangType.h" // uint32_t
#include "EBNFRewriter.h" // ebnf2bnf
#include <stdio.h> // size_t
#include <stdarg.h> // va_start
#include <string> // std::string
#include <sstream> // std::stringstream
#include <iostream> // std::cout
#include <stdlib.h> // EXIT_SUCCESS
#include <getopt.h> // getopt_long

#define MAKE_TERM(sym_id, ...)   xl::mvc::MVCModel::make_term(tree_context(), sym_id, ##__VA_ARGS__)
#define MAKE_SYMBOL(...)         xl::mvc::MVCModel::make_symbol(tree_context(), ##__VA_ARGS__)
#define ERROR_SYM_ID_NOT_FOUND   "missing sym_id handler, most likely you forgot to register one"
#define ERROR_SYM_NAME_NOT_FOUND "missing sym name handler, most likely you forgot to register one"
#define EOL                      xl::node::SymbolNode::eol();

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
std::string id_to_name(uint32_t sym_id)
{
    static const char* _id_to_name[] = {
        "int",
        "float",
        "string",
        "char",
        "ident"
        };
    int index = static_cast<int>(sym_id)-ID_BASE-1;
    if(index >= 0 && index < static_cast<int>(sizeof(_id_to_name)/sizeof(*_id_to_name)))
        return _id_to_name[index];
    switch(sym_id)
    {
        case ID_GRAMMAR:      return "grammar";
        case ID_DEFINITIONS:  return "definitions";
        case ID_DECL:         return "decl";
        case ID_DECL_EQ:      return "decl_eq";
        case ID_DECL_BRACE:   return "decl_brace";
        case ID_PROTO_BLOCK:  return "proto_block";
        case ID_UNION_BLOCK:  return "union_block";
        case ID_DECL_STMTS:   return "decl_stmts";
        case ID_DECL_STMT:    return "decl_stmt";
        case ID_SYMBOLS:      return "symbols";
        case ID_RULES:        return "rules";
        case ID_RULE:         return "rule";
        case ID_ALTS:         return "alts";
        case ID_ALT:          return "alt";
        case ID_ACTION_BLOCK: return "action_block";
        case ID_TERMS:        return "terms";
        case ID_CODE:         return "code";
        case '+':             return "+";
        case '*':             return "*";
        case '?':             return "?";
        case '(':             return "(";
    }
    throw ERROR_SYM_ID_NOT_FOUND;
    return "";
}
uint32_t name_to_id(std::string name)
{
    if(name == "int")          return ID_INT;
    if(name == "float")        return ID_FLOAT;
    if(name == "string")       return ID_STRING;
    if(name == "char")         return ID_CHAR;
    if(name == "ident")        return ID_IDENT;
    if(name == "grammar")      return ID_GRAMMAR;
    if(name == "definitions")  return ID_DEFINITIONS;
    if(name == "decl")         return ID_DECL;
    if(name == "decl_eq")      return ID_DECL_EQ;
    if(name == "decl_brace")   return ID_DECL_BRACE;
    if(name == "proto_block")  return ID_PROTO_BLOCK;
    if(name == "union_block")  return ID_UNION_BLOCK;
    if(name == "decl_stmts")   return ID_DECL_STMTS;
    if(name == "decl_stmt")    return ID_DECL_STMT;
    if(name == "symbols")      return ID_SYMBOLS;
    if(name == "rules")        return ID_RULES;
    if(name == "rule")         return ID_RULE;
    if(name == "alts")         return ID_ALTS;
    if(name == "alt")          return ID_ALT;
    if(name == "action_block") return ID_ACTION_BLOCK;
    if(name == "terms")        return ID_TERMS;
    if(name == "code")         return ID_CODE;
    if(name == "+")            return '+';
    if(name == "*")            return '*';
    if(name == "?")            return '?';
    if(name == "(")            return '(';
    throw ERROR_SYM_NAME_NOT_FOUND;
    return 0;
}
xl::TreeContext* &tree_context()
{
    static xl::TreeContext* tc = NULL;
    return tc;
}

%}

// type of yylval to be set by scanner actions
// implemented as %union in non-reentrant mode
//
%union
{
    xl::node::TermInternalType<xl::node::NodeIdentIFace::INT>::type     int_value;    // int value
    xl::node::TermInternalType<xl::node::NodeIdentIFace::FLOAT>::type   float_value;  // float value
    xl::node::TermInternalType<xl::node::NodeIdentIFace::STRING>::type* string_value; // string value
    xl::node::TermInternalType<xl::node::NodeIdentIFace::CHAR>::type    char_value;   // char value
    xl::node::TermInternalType<xl::node::NodeIdentIFace::IDENT>::type   ident_value;  // symbol table index
    xl::node::TermInternalType<xl::node::NodeIdentIFace::SYMBOL>::type  symbol_value; // node pointer
}

// show detailed parse errors
%error-verbose

%nonassoc ID_BASE

%token<int_value>    ID_INT
%token<float_value>  ID_FLOAT
%token<string_value> ID_STRING
%token<char_value>   ID_CHAR
%token<ident_value>  ID_IDENT
%type<symbol_value>  grammar definitions definition
        proto_block union_block decl_stmts decl_stmt
        symbols symbol rules rule alts alt action_block terms term code

%nonassoc ID_GRAMMAR ID_DEFINITIONS ID_DECL ID_DECL_EQ ID_DECL_BRACE
        ID_PROTO_BLOCK ID_UNION_BLOCK ID_DECL_STMTS ID_DECL_STMT
        ID_SYMBOLS ID_RULES ID_RULE ID_ALTS ID_ALT ID_ACTION_BLOCK ID_TERMS ID_FENCE ID_CODE
%nonassoc ':'
%nonassoc '|' '(' ';'
%nonassoc '+' '*' '?'

%nonassoc ID_COUNT

%%

root:
      grammar { tree_context()->root() = $1; YYACCEPT; }
    | error   { yyclearin; /* yyerrok; YYABORT; */ }
    ;

grammar:
      definitions ID_FENCE rules ID_FENCE code {
                $$ = MAKE_SYMBOL(ID_GRAMMAR, 3, $1, $3, $5);
            }
    ;

//=============================================================================
// DEFINITIONS SECTION

definitions:
      /* empty */            { $$ = EOL; }
    | definitions definition { $$ = MAKE_SYMBOL(ID_DEFINITIONS, 2, $1, $2); }
    ;

definition:
      '%' ID_IDENT                     { $$ = MAKE_SYMBOL(ID_DECL, 1, MAKE_TERM(ID_IDENT, $2)); }
    | '%' ID_IDENT symbols             { $$ = MAKE_SYMBOL(ID_DECL, 2, MAKE_TERM(ID_IDENT, $2), $3); }
    | '%' ID_IDENT '{' union_block '}' { $$ = MAKE_SYMBOL(ID_DECL, 2, MAKE_TERM(ID_IDENT, $2), $4); }
    | '%' ID_IDENT '=' ID_STRING {
                $$ = MAKE_SYMBOL(ID_DECL_EQ, 2,
                        MAKE_TERM(ID_IDENT, $2),
                        MAKE_TERM(ID_STRING, *$4)); // NOTE: asterisk..
            }
    | '%' ID_IDENT '<' ID_IDENT '>' symbols {
                $$ = MAKE_SYMBOL(ID_DECL_BRACE, 3,
                        MAKE_TERM(ID_IDENT, $2),
                        MAKE_TERM(ID_IDENT, $4),
                        $6);
            }
    | proto_block { $$ = $1; }
    ;

symbols:
      symbol         { $$ = MAKE_SYMBOL(ID_SYMBOLS, 1, $1); }
    | symbols symbol { $$ = MAKE_SYMBOL(ID_SYMBOLS, 2, $1, $2); }
    ;

symbol:
      ID_IDENT { $$ = MAKE_TERM(ID_IDENT, $1); }
    | ID_CHAR  { $$ = MAKE_TERM(ID_CHAR, $1); }
    ;

union_block:
      decl_stmts { $$ = MAKE_SYMBOL(ID_UNION_BLOCK, 1, $1); }
    ;

decl_stmts:
      /* empty */          { $$ = EOL; }
    | decl_stmts decl_stmt { $$ = MAKE_SYMBOL(ID_DECL_STMTS, 2, $1, $2); }
    ;

decl_stmt:
    ID_IDENT ID_IDENT ';' {
                $$ = MAKE_SYMBOL(ID_DECL_STMT, 2,
                        MAKE_TERM(ID_IDENT, $1),
                        MAKE_TERM(ID_IDENT, $2));
          }
    ;

proto_block:
      ID_STRING {
                $$ = (!$1->empty()) ? MAKE_SYMBOL(ID_PROTO_BLOCK, 1,
                        MAKE_TERM(ID_STRING, *$1)) : NULL; // NOTE: asterisk..
            }
    ;

//=============================================================================
// RULES SECTION

rules:
      /* empty */ { $$ = EOL; }
    | rules rule  { $$ = MAKE_SYMBOL(ID_RULES, 2, $1, $2); }
    ;

rule:
      ID_IDENT ':' alts ';' {
                $$ = MAKE_SYMBOL(ID_RULE, 2, MAKE_TERM(ID_IDENT, $1), $3);
            }
    ;

alts:
      alt          { $$ = MAKE_SYMBOL(ID_ALTS, 1, $1); }
    | alts '|' alt { $$ = MAKE_SYMBOL(ID_ALTS, 2, $1, $3); }
    ;

alt:
      terms action_block { $$ = MAKE_SYMBOL(ID_ALT, 2, $1, $2); }
    ;

action_block:
      /* empty */ { $$ = EOL; }
    | ID_STRING {
                $$ = (!$1->empty()) ? MAKE_SYMBOL(ID_ACTION_BLOCK, 1,
                        MAKE_TERM(ID_STRING, *$1)) : NULL; // NOTE: asterisk..
            }
    ;

terms:
      /* empty */ { $$ = EOL; }
    | terms term  { $$ = MAKE_SYMBOL(ID_TERMS, 2, $1, $2); }
    ;

term:
      ID_INT       { $$ = MAKE_TERM(ID_INT, $1); }
    | ID_FLOAT     { $$ = MAKE_TERM(ID_FLOAT, $1); }
    | ID_STRING    { $$ = MAKE_TERM(ID_STRING, *$1); } // NOTE: asterisk..
    | ID_CHAR      { $$ = MAKE_TERM(ID_CHAR, $1); }
    | ID_IDENT     { $$ = MAKE_TERM(ID_IDENT, $1); }
    | term '+'     { $$ = MAKE_SYMBOL('+', 1, $1); }
    | term '*'     { $$ = MAKE_SYMBOL('*', 1, $1); }
    | term '?'     { $$ = MAKE_SYMBOL('?', 1, $1); }
    | '(' alts ')' { $$ = MAKE_SYMBOL('(', 1, $2); }
    ;

//=============================================================================
// CODE

code:
      ID_STRING {
                $$ = (!$1->empty()) ? MAKE_SYMBOL(ID_CODE, 1,
                        MAKE_TERM(ID_STRING, *$1)) : NULL; // NOTE: asterisk..
            }
    ;

%%

xl::node::NodeIdentIFace* make_ast(xl::Allocator &alloc)
{
    tree_context() = new (PNEW(alloc, xl::, TreeContext)) xl::TreeContext(alloc);
    int error = _XLANG_parse(); // parser entry point
    _XLANG_lex_destroy();
    return (!error && errors().str().empty()) ? tree_context()->root() : NULL;
}

void display_usage(bool verbose)
{
    std::cout << "Usage: XLang [-i] OPTION [-m]" << std::endl;
    if(verbose)
    {
        std::cout << "Parses input and prints a syntax tree to standard out" << std::endl
                << std::endl
                << "Input control:" << std::endl
                << "  -i, --in-xml=FILE (de-serialize from xml)" << std::endl
                << std::endl
                << "Output control:" << std::endl
                << "  -y, --yacc" << std::endl
                << "  -l, --lisp" << std::endl
                << "  -x, --xml" << std::endl
                << "  -g, --graph" << std::endl
                << "  -d, --dot" << std::endl
                << "  -m, --memory" << std::endl;
    }
    else
        std::cout << "Try `XLang --help\' for more information." << std::endl;
}

struct args_t
{
    typedef enum
    {
        MODE_NONE,
        MODE_YACC,
        MODE_LISP,
        MODE_XML,
        MODE_GRAPH,
        MODE_DOT,
        MODE_HELP
    } mode_e;

    mode_e mode;
    std::string in_xml;
    bool dump_memory;

    args_t()
        : mode(MODE_NONE), dump_memory(false)
    {}
};

bool parse_args(int argc, char** argv, args_t &args)
{
    int opt = 0;
    int longIndex = 0;
    static const char *optString = "i:ylxgdmh?";
    static const struct option longOpts[] = {
                { "in-xml", required_argument, NULL, 'i' },
                { "yacc",   no_argument,       NULL, 'y' },
                { "lisp",   no_argument,       NULL, 'l' },
                { "xml",    no_argument,       NULL, 'x' },
                { "graph",  no_argument,       NULL, 'g' },
                { "dot",    no_argument,       NULL, 'd' },
                { "memory", no_argument,       NULL, 'm' },
                { "help",   no_argument,       NULL, 'h' },
                { NULL,     no_argument,       NULL, 0 }
            };
    opt = getopt_long(argc, argv, optString, longOpts, &longIndex);
    while(opt != -1)
    {
        switch(opt)
        {
            case 'i': args.in_xml = optarg; break;
            case 'y': args.mode = args_t::MODE_YACC; break;
            case 'l': args.mode = args_t::MODE_LISP; break;
            case 'x': args.mode = args_t::MODE_XML; break;
            case 'g': args.mode = args_t::MODE_GRAPH; break;
            case 'd': args.mode = args_t::MODE_DOT; break;
            case 'm': args.dump_memory = true; break;
            case 'h':
            case '?': args.mode = args_t::MODE_HELP; break;
            case 0: // reserved
            default:
                break;
        }
        opt = getopt_long(argc, argv, optString, longOpts, &longIndex);
    }
    if(args_t::MODE_NONE == args.mode && !args.dump_memory)
    {
        display_usage(false);
        return false;
    }
    return true;
}

bool import_ast(args_t &args, xl::Allocator &alloc, xl::node::NodeIdentIFace* &ast)
{
    if(args.in_xml != "")
    {
        ast = xl::mvc::MVCModel::make_ast(
                new (PNEW(alloc, xl::, TreeContext)) xl::TreeContext(alloc),
                args.in_xml);
        if(!ast)
        {
            std::cout << "de-serialize from xml fail!" << std::endl;
            return false;
        }
    }
    else
    {
        ast = make_ast(alloc);
        if(!ast)
        {
            std::cout << errors().str().c_str() << std::endl;
            return false;
        }
    }
    return true;
}

void export_ast(args_t &args, xl::node::NodeIdentIFace* ast)
{
    switch(args.mode)
    {
        case args_t::MODE_YACC:  ebnf2bnf(tree_context(), ast); break;
        case args_t::MODE_LISP:  xl::mvc::MVCView::print_lisp(ast); break;
        case args_t::MODE_XML:   xl::mvc::MVCView::print_xml(ast); break;
        case args_t::MODE_GRAPH: xl::mvc::MVCView::print_graph(ast); break;
        case args_t::MODE_DOT:   xl::mvc::MVCView::print_dot(ast); break;
        default:
            break;
    }
}

bool do_work(args_t &args)
{
    try
    {
        if(args.mode == args_t::MODE_HELP)
        {
            display_usage(true);
            return true;
        }
        xl::Allocator alloc(__FILE__);
        xl::node::NodeIdentIFace* ast = NULL;
        if(!import_ast(args, alloc, ast))
            return false;
        export_ast(args, ast);
        if(args.dump_memory)
            alloc.dump(std::string(1, '\t'));
    }
    catch(const char* s)
    {
        std::cout << "ERROR: " << s << std::endl;
        return false;
    }
    return true;
}

int main(int argc, char** argv)
{
    args_t args;
    if(!parse_args(argc, argv, args))
        return EXIT_FAILURE;
    if(!do_work(args))
        return EXIT_FAILURE;
    return EXIT_SUCCESS;
}
