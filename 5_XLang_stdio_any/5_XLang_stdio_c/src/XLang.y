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
#include "node/XLangNodePrinterVisitor.h" // node::NodePrinterVisitor
#include "XLangType.h" // uint32_t
#include <stdio.h> // size_t
#include <stdarg.h> // va_start
#include <string.h> // strlen
#include <string> // std::string
#include <sstream> // std::stringstream
#include <iostream> // std::cout
#include <stdlib.h> // EXIT_SUCCESS
#include <getopt.h> // getopt_long

#define MAKE_LEAF(sym_id, ...) mvc::MVCModel::make_leaf(parse_context(), sym_id, ##__VA_ARGS__)
#define MAKE_INNER(...) mvc::MVCModel::make_inner(parse_context(), ##__VA_ARGS__)

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
std::string sym_name(uint32_t sym_id)
{
    return "";
    static const char* _sym_name[ID_COUNT - ID_BASE - 1] = {
        "IDENTIFIER", "ID_INT", "ID_FLOAT",
        "CONSTANT", "STRING_LITERAL", "SIZEOF",
        "PTR_OP", "INC_OP", "DEC_OP", "LEFT_OP", "RIGHT_OP", "LE_OP", "GE_OP", "EQ_OP", "NE_OP",
        "AND_OP", "OR_OP", "MUL_ASSIGN", "DIV_ASSIGN", "MOD_ASSIGN", "ADD_ASSIGN",
        "SUB_ASSIGN", "LEFT_ASSIGN", "RIGHT_ASSIGN", "AND_ASSIGN",
        "XOR_ASSIGN", "OR_ASSIGN", "TYPE_NAME",

        "TYPEDEF", "EXTERN", "STATIC", "AUTO", "REGISTER",
        "CHAR", "SHORT", "INT", "LONG", "SIGNED", "UNSIGNED", "FLOAT", "DOUBLE", "CONST", "VOLATILE", "VOID",
        "STRUCT", "UNION", "ENUM", "ELLIPSIS",

        "CASE", "DEFAULT", "IF", "ELSE", "SWITCH", "WHILE", "DO", "FOR", "GOTO", "CONTINUE", "BREAK", "RETURN",
        };
    switch(sym_id)
    {
    case '+': return "+";
    case '-': return "-";
    case '*': return "*";
    case '/': return "/";
    case '%': return "%";
    case '^': return "^";
    case '&': return "&";
    case '|': return "|";
    case '=': return "=";
    case ',': return ",";
    }
    return _sym_name[sym_id - ID_BASE - 1];
}
ParserContext* &parse_context()
{
    static ParserContext* pc = NULL;
    return pc;
}

%}

// type of yylval to be set by scanner actions
// implemented as %union in non-reentrant mode
//
%union
{
    long int_value; // int value
    float32_t float_value; // float value
    const std::string* ident_value; // symbol table index
    node::NodeIdentIFace* inner_value; // node pointer
}

// show detailed parse errors
%error-verbose

%nonassoc ID_BASE

%type<inner_value> primary_expression postfix_expression unary_expression unary_operator
        multiplicative_expression additive_expression shift_expression relational_expression
        equality_expression and_expression exclusive_or_expression inclusive_or_expression
        logical_and_expression logical_or_expression conditional_expression assignment_expression
        assignment_operator expression type_specifier statement compound_statement statement_list
        expression_statement

%token<ident_value> IDENTIFIER
%token<int_value> ID_INT
%token<float_value> ID_FLOAT

%token CONSTANT STRING_LITERAL SIZEOF
%token PTR_OP INC_OP DEC_OP LEFT_OP RIGHT_OP LE_OP GE_OP EQ_OP NE_OP
%token AND_OP OR_OP MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN ADD_ASSIGN
%token SUB_ASSIGN LEFT_ASSIGN RIGHT_ASSIGN AND_ASSIGN
%token XOR_ASSIGN OR_ASSIGN TYPE_NAME

%token TYPEDEF EXTERN STATIC AUTO REGISTER
%token CHAR SHORT INT LONG SIGNED UNSIGNED FLOAT DOUBLE CONST VOLATILE VOID
%token STRUCT UNION ENUM ELLIPSIS

%token CASE DEFAULT IF ELSE SWITCH WHILE DO FOR GOTO CONTINUE BREAK RETURN

//%start translation_unit
%start root

%nonassoc ID_COUNT

%%

///////////////////////////////////////////////////////////////////////////////
//root:
//      program { parse_context()->root() = $1; YYACCEPT; }
//    | error   { yyclearin; /* yyerrok; YYABORT; */ }
//    ;
//
//program:
//      statement             { $$ = $1; }
//    | statement ',' program { $$ = MAKE_INNER(',', 2, $1, $3); }
//    ;
//
//statement:
//      expression                { $$ = $1; }
//    | IDENTIFIER '=' expression { $$ = MAKE_INNER('=', 2, MAKE_LEAF(IDENTIFIER, $1), $3); }
//    ;
//
//expression:
//      ID_INT                    { $$ = MAKE_LEAF(ID_INT, $1); }
//    | ID_FLOAT                  { $$ = MAKE_LEAF(ID_FLOAT, $1); }
//    | IDENTIFIER                { $$ = MAKE_LEAF(IDENTIFIER, $1); }
//    | expression '+' expression { $$ = MAKE_INNER('+', 2, $1, $3); }
//    | expression '-' expression { $$ = MAKE_INNER('-', 2, $1, $3); }
//    | expression '*' expression { $$ = MAKE_INNER('*', 2, $1, $3); }
//    | expression '/' expression { $$ = MAKE_INNER('/', 2, $1, $3); }
//    | '(' expression ')'        { $$ = $2; }
//    ;
///////////////////////////////////////////////////////////////////////////////

root
    : statement { parse_context()->root() = $1; YYACCEPT; }
    | error     { yyclearin; /* yyerrok; YYABORT; */ }
    ;

primary_expression
    : IDENTIFIER         { $$ = MAKE_LEAF(IDENTIFIER, $1); }
    | ID_INT             { $$ = MAKE_LEAF(ID_INT, $1); }
    | ID_FLOAT           { $$ = MAKE_LEAF(ID_FLOAT, $1); }
    //| STRING_LITERAL
    | '(' expression ')' { $$ = $2; }
    ;

postfix_expression
    : primary_expression
    | postfix_expression '[' expression ']'
    | postfix_expression '(' ')'
    //| postfix_expression '(' argument_expression_list ')'
    | postfix_expression '.' IDENTIFIER
    | postfix_expression PTR_OP IDENTIFIER
    | postfix_expression INC_OP
    | postfix_expression DEC_OP
    ;

//argument_expression_list
//    : assignment_expression
//    | argument_expression_list ',' assignment_expression
//    ;

unary_expression
    : postfix_expression
    | INC_OP unary_expression
    | DEC_OP unary_expression
    //| unary_operator cast_expression
    | SIZEOF unary_expression
    //| SIZEOF '(' type_name ')'
    ;

unary_operator
    //: '&'
    //| '*'
    : '+'
    | '-'
    | '~'
    | '!'
    ;

//cast_expression
//    : unary_expression
//    | '(' type_name ')' cast_expression
//    ;

multiplicative_expression
    : unary_expression
    | multiplicative_expression '*' unary_expression
    | multiplicative_expression '/' unary_expression
    | multiplicative_expression '%' unary_expression
    ;

additive_expression
    : multiplicative_expression
    | additive_expression '+' multiplicative_expression
    | additive_expression '-' multiplicative_expression
    ;

shift_expression
    : additive_expression
    | shift_expression LEFT_OP additive_expression
    | shift_expression RIGHT_OP additive_expression
    ;

relational_expression
    : shift_expression
    | relational_expression '<' shift_expression
    | relational_expression '>' shift_expression
    | relational_expression LE_OP shift_expression
    | relational_expression GE_OP shift_expression
    ;

equality_expression
    : relational_expression
    | equality_expression EQ_OP relational_expression
    | equality_expression NE_OP relational_expression
    ;

and_expression
    : equality_expression
    | and_expression '&' equality_expression
    ;

exclusive_or_expression
    : and_expression
    | exclusive_or_expression '^' and_expression
    ;

inclusive_or_expression
    : exclusive_or_expression
    | inclusive_or_expression '|' exclusive_or_expression
    ;

logical_and_expression
    : inclusive_or_expression
    | logical_and_expression AND_OP inclusive_or_expression
    ;

logical_or_expression
    : logical_and_expression
    | logical_or_expression OR_OP logical_and_expression
    ;

conditional_expression
    : logical_or_expression
    | logical_or_expression '?' expression ':' conditional_expression
    ;

assignment_expression
    : conditional_expression
    | unary_expression assignment_operator assignment_expression
    ;

assignment_operator
    : '='
    | MUL_ASSIGN
    | DIV_ASSIGN
    | MOD_ASSIGN
    | ADD_ASSIGN
    | SUB_ASSIGN
    | LEFT_ASSIGN
    | RIGHT_ASSIGN
    | AND_ASSIGN
    | XOR_ASSIGN
    | OR_ASSIGN
    ;

expression
    : assignment_expression
    | expression ',' assignment_expression
    ;

//constant_expression
//    : conditional_expression
//    ;
//
//declaration
//    : declaration_specifiers ';'
//    | declaration_specifiers init_declarator_list ';'
//    ;
//
//declaration_specifiers
//    : storage_class_specifier
//    | storage_class_specifier declaration_specifiers
//    | type_specifier
//    | type_specifier declaration_specifiers
//    | type_qualifier
//    | type_qualifier declaration_specifiers
//    ;
//
//init_declarator_list
//    : init_declarator
//    | init_declarator_list ',' init_declarator
//    ;
//
//init_declarator
//    : declarator
//    | declarator '=' initializer
//    ;
//
//storage_class_specifier
//    : TYPEDEF
//    | EXTERN
//    | STATIC
//    | AUTO
//    | REGISTER
//    ;

type_specifier
    : VOID
    | CHAR
    | SHORT
    | INT
    | LONG
    | FLOAT
    | DOUBLE
    | SIGNED
    | UNSIGNED
//    | struct_or_union_specifier
//    | enum_specifier
//    | TYPE_NAME
    ;

//struct_or_union_specifier
//    : struct_or_union IDENTIFIER '{' struct_declaration_list '}'
//    | struct_or_union '{' struct_declaration_list '}'
//    | struct_or_union IDENTIFIER
//    ;
//
//struct_or_union
//    : STRUCT
//    | UNION
//    ;
//
//struct_declaration_list
//    : struct_declaration
//    | struct_declaration_list struct_declaration
//    ;
//
//struct_declaration
//    : specifier_qualifier_list struct_declarator_list ';'
//    ;
//
//specifier_qualifier_list
//    : type_specifier specifier_qualifier_list
//    | type_specifier
//    | type_qualifier specifier_qualifier_list
//    | type_qualifier
//    ;
//
//struct_declarator_list
//    : struct_declarator
//    | struct_declarator_list ',' struct_declarator
//    ;
//
//struct_declarator
//    : declarator
//    | ':' constant_expression
//    | declarator ':' constant_expression
//    ;
//
//enum_specifier
//    : ENUM '{' enumerator_list '}'
//    | ENUM IDENTIFIER '{' enumerator_list '}'
//    | ENUM IDENTIFIER
//    ;
//
//enumerator_list
//    : enumerator
//    | enumerator_list ',' enumerator
//    ;
//
//enumerator
//    : IDENTIFIER
//    | IDENTIFIER '=' constant_expression
//    ;
//
//type_qualifier
//    : CONST
//    | VOLATILE
//    ;
//
//declarator
//    : pointer direct_declarator
//    | direct_declarator
//    ;
//
//direct_declarator
//    : IDENTIFIER
//    | '(' declarator ')'
//    | direct_declarator '[' constant_expression ']'
//    | direct_declarator '[' ']'
//    | direct_declarator '(' parameter_type_list ')'
//    | direct_declarator '(' identifier_list ')'
//    | direct_declarator '(' ')'
//    ;
//
//pointer
//    : '*'
//    | '*' type_qualifier_list
//    | '*' pointer
//    | '*' type_qualifier_list pointer
//    ;
//
//type_qualifier_list
//    : type_qualifier
//    | type_qualifier_list type_qualifier
//    ;
//
//
//parameter_type_list
//    : parameter_list
//    | parameter_list ',' ELLIPSIS
//    ;
//
//parameter_list
//    : parameter_declaration
//    | parameter_list ',' parameter_declaration
//    ;
//
//parameter_declaration
//    : declaration_specifiers declarator
//    | declaration_specifiers abstract_declarator
//    | declaration_specifiers
//    ;
//
//identifier_list
//    : IDENTIFIER
//    | identifier_list ',' IDENTIFIER
//    ;
//
//type_name
//    : specifier_qualifier_list
//    | specifier_qualifier_list abstract_declarator
//    ;
//
//abstract_declarator
//    : pointer
//    | direct_abstract_declarator
//    | pointer direct_abstract_declarator
//    ;
//
//direct_abstract_declarator
//    : '(' abstract_declarator ')'
//    | '[' ']'
//    | '[' constant_expression ']'
//    | direct_abstract_declarator '[' ']'
//    | direct_abstract_declarator '[' constant_expression ']'
//    | '(' ')'
//    | '(' parameter_type_list ')'
//    | direct_abstract_declarator '(' ')'
//    | direct_abstract_declarator '(' parameter_type_list ')'
//    ;
//
//initializer
//    : assignment_expression
//    | '{' initializer_list '}'
//    | '{' initializer_list ',' '}'
//    ;
//
//initializer_list
//    : initializer
//    | initializer_list ',' initializer
//    ;

statement
//    : labeled_statement
    : compound_statement
    | expression_statement
//    | selection_statement
//    | iteration_statement
//    | jump_statement
    ;

//labeled_statement
//    : IDENTIFIER ':' statement
//    | CASE constant_expression ':' statement
//    | DEFAULT ':' statement
//    ;

compound_statement
    : '{' '}'
    | '{' statement_list '}'
//    | '{' declaration_list '}'
//    | '{' declaration_list statement_list '}'
    ;

//declaration_list
//    : declaration
//    | declaration_list declaration
//    ;

statement_list
    : statement
    | statement_list statement
    ;

expression_statement
    : ';'
    | expression ';'
    ;

//selection_statement
//    : IF '(' expression ')' statement
//    | IF '(' expression ')' statement ELSE statement
//    | SWITCH '(' expression ')' statement
//    ;
//
//iteration_statement
//    : WHILE '(' expression ')' statement
//    | DO statement WHILE '(' expression ')' ';'
//    | FOR '(' expression_statement expression_statement ')' statement
//    | FOR '(' expression_statement expression_statement expression ')' statement
//    ;
//
//jump_statement
//    : GOTO IDENTIFIER ';'
//    | CONTINUE ';'
//    | BREAK ';'
//    | RETURN ';'
//    | RETURN expression ';'
//    ;
//
//translation_unit
//    : external_declaration
//    | translation_unit external_declaration
//    ;
//
//external_declaration
//    : function_definition
//    | declaration
//    ;
//
//function_definition
//    : declaration_specifiers declarator declaration_list compound_statement
//    | declaration_specifiers declarator compound_statement
//    | declarator declaration_list compound_statement
//    | declarator compound_statement
//    ;

%%

const std::string* ParserContext::alloc_unique_string(std::string name)
{
    string_set_t::iterator p = m_string_set.find(&name);
    if(p == m_string_set.end())
    {
        m_string_set.insert(new (m_alloc, __FILE__, __LINE__, [](void *x) {
                reinterpret_cast<std::string*>(x)->~basic_string();
                }) std::string(name));
        p = m_string_set.find(&name);
    }
    return *p;
}

node::NodeIdentIFace* make_ast(Allocator &alloc)
{
    parse_context() = new (alloc, __FILE__, __LINE__, [](void* x) {
            reinterpret_cast<ParserContext*>(x)->~ParserContext();
            }) ParserContext(alloc);
    int error = _XLANG_parse(); // parser entry point
    _XLANG_lex_destroy();
    return ((0 == error) && errors().str().empty()) ? parse_context()->root() : NULL;
}

void display_usage(bool verbose)
{
    std::cout << "Usage: XLang OPTION [-m]" << std::endl;
    if(verbose)
        std::cout << "Parses input and prints a syntax tree to standard out" << std::endl
                << "Output control:" << std::endl
                << "  -l, --lisp" << std::endl
                << "  -g, --graph" << std::endl
                << "  -d, --dot" << std::endl
                << "  -m, --memory" << std::endl;
    else
        std::cout << "Try `XLang --help\' for more information." << std::endl;
}

struct args_t
{
    typedef enum
    {
        MODE_NONE,
        MODE_LISP,
        MODE_GRAPH,
        MODE_DOT,
        MODE_HELP
    } mode_e;

    mode_e mode;
    bool dump_memory;

    args_t()
        : mode(MODE_NONE), dump_memory(false) {}
};

bool parse_args(int argc, char** argv, args_t &args)
{
    int opt = 0;
    int longIndex = 0;
    static const char *optString = "lgdmh?";
    static const struct option longOpts[] = {
                { "lisp",   no_argument, NULL, 'l' },
                { "graph",  no_argument, NULL, 'g' },
                { "dot",    no_argument, NULL, 'd' },
                { "memory", no_argument, NULL, 'm' },
                { "help",   no_argument, NULL, 'h' },
                { NULL,     no_argument, NULL, 0 }
            };
    opt = getopt_long(argc, argv, optString, longOpts, &longIndex);
    while(opt != -1)
    {
        switch(opt)
        {
            case 'l': args.mode = args_t::MODE_LISP; break;
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
    if(args_t::MODE_NONE == args.mode)
    {
        display_usage(false);
        return false;
    }
    return true;
}

bool do_work(args_t &args)
{
    Allocator alloc(__FILE__);
    node::NodeIdentIFace* ast = make_ast(alloc);
    if(NULL == ast)
    {
        std::cout << errors().str().c_str() << std::endl;
        return false;
    }
    switch(args.mode)
    {
        case args_t::MODE_LISP:
            {
                #if 1 // use mvc-pattern pretty-printer
                    mvc::MVCView::print_lisp(ast); std::cout << std::endl;
                #else // use visitor-pattern pretty-printer
                    node::NodePrinterVisitor visitor;
                    if(ast->type() == node::NodeIdentIFace::INNER)
                    {
                        dynamic_cast<const node::InnerNode*>(ast)->accept(&visitor);
                        std::cout << std::endl;
                    }
                    else
                        std::cout << "visitor can only print inner-node" << std::endl;
                #endif
            }
            break;
        case args_t::MODE_GRAPH: mvc::MVCView::print_graph(ast); break;
        case args_t::MODE_DOT:   mvc::MVCView::print_dot(ast); break;
        case args_t::MODE_HELP:  display_usage(true); break;
        default:
            break;
    }
    if(args.dump_memory)
        alloc.dump(std::string(1, '\t'));
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