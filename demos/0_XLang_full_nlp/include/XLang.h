// XLang
// -- A parser framework for language modeling
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

#ifndef XLANG_H_
#define XLANG_H_

#include "XLangType.h" // uint32_t
#include "XLangAlloc.h" // Allocator
#include "node/XLangNodeIFace.h" // node::NodeIdentIFace
#include "XLang.tab.h" // YYLTYPE (generated)
#include "XLangTreeContext.h" // TreeContext
#include <vector> // std::vector
#include <list> // std::list
#include <map> // std::map
#include <string> // std::string
#include <sstream> // std::stringstream

// type of yylval to be set by scanner actions
// implemented as %union in non-reentrant mode
struct SynthAttrib
{
    union
    {
        xl::node::TermInternalType<xl::node::NodeIdentIFace::INT>::type    int_value;    // int value
        xl::node::TermInternalType<xl::node::NodeIdentIFace::FLOAT>::type  float_value;  // float value
        xl::node::TermInternalType<xl::node::NodeIdentIFace::STRING>::type string_value; // string value
        xl::node::TermInternalType<xl::node::NodeIdentIFace::CHAR>::type   char_value;   // char value
        xl::node::TermInternalType<xl::node::NodeIdentIFace::IDENT>::type  ident_value;  // symbol table index
        xl::node::TermInternalType<xl::node::NodeIdentIFace::SYMBOL>::type symbol_value; // node pointer
    };
};
#define YYSTYPE SynthAttrib

#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
    typedef void* yyscan_t;
#endif
struct ScannerContext
{
    yyscan_t m_scanner; // state of the lexer

    const char* m_buf;    // buffer we read from
    int         m_pos;    // current position in buf
    int         m_length; // length of buf

    // location placeholders
    int m_line;
    int m_column;
    int m_prev_column;
    int m_word_index;

    std::map<std::string, uint32_t>* m_lexer_id_map;
    std::vector<uint32_t>*           m_pos_lexer_id_path;

    ScannerContext(const char* buf);
    uint32_t word_to_lexer_id(std::string word);
    uint32_t current_lexer_id();
};

// context type to hold shared data between bison and flex
class ParserContext
{
public:
    ParserContext(xl::Allocator &alloc, const char* buf)
        : m_tree_context(alloc), m_scanner_context(buf)
    {}
    xl::TreeContext &tree_context()
    {
        return m_tree_context;
    }
    ScannerContext &scanner_context()
    {
        return m_scanner_context;
    }

private:
    xl::TreeContext m_tree_context;
    ScannerContext  m_scanner_context;
};
#define YY_EXTRA_TYPE ParserContext*

// forward declaration of lexer/parser functions
// so the compiler shuts up about warnings
#define _xl(x) _XLANG_##x
int _xl(lex)(YYSTYPE*, YYLTYPE*, yyscan_t);
int _xl(lex_init)(yyscan_t*);
int _xl(lex_destroy)(yyscan_t);
void _xl(set_extra)(YY_EXTRA_TYPE, yyscan_t);
int _xl(parse)(ParserContext*, yyscan_t);
void _xl(error)(YYLTYPE* loc, ParserContext* pc, yyscan_t scanner, const char* s);
void _xl(error)(const char* s);
//#undef _xl

std::stringstream &error_messages();
std::string id_to_name(uint32_t lexer_id);
uint32_t name_to_id(std::string name);

xl::node::NodeIdentIFace* make_ast(
        xl::Allocator &alloc, const char* s,
        std::map<std::string, uint32_t>* lexer_id_map,
        std::vector<uint32_t> &pos_lexer_id_path);

#endif
