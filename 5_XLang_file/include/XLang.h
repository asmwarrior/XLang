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

#ifndef _XLANG_H_
#define _XLANG_H_

#include "XLangType.h" // uint32
#include "XLangAlloc.h" // Allocator
#include "XLangNodeBase.h" // node::NodeBase
#include "XLangParseContextBase.h" // ParseContextBase
#include <stdio.h> // FILE
#include <string> // std::string
#include <set> // std::set
#include <sstream> // std::stringstream

struct ScanContext
{
    FILE* m_file; // buffer we read from
    int   m_pos; // current position in buf
    int   m_length; // length of buf

    ScanContext(FILE* file);
};

// context type to hold shared data between bison and flex
class ParseContext : public ParseContextBase
{
private:
    Allocator      &m_alloc;
    ScanContext     m_sc;
    node::NodeBase* m_root; // parse result (AST root)
    typedef std::set<std::string> name_set_t;
    name_set_t m_name_set;

public:
    ParseContext(Allocator &alloc, FILE* file)
        : m_alloc(alloc), m_sc(file), m_root(NULL) {}
    Allocator       &alloc()        { return m_alloc; }
    ScanContext     &scan_context() { return m_sc; }
    node::NodeBase* &root()         { return m_root; }

    const std::string* get_insert_name(std::string name)
    {
        name_set_t::iterator p = m_name_set.find(name);
        if(p == m_name_set.end())
        {
            m_name_set.insert(name);
            p = m_name_set.find(name);
        }
        return &(*p);
    }
};

// forward declaration of lexer/parser functions 
// so the compiler shuts up about warnings
//
int _XLANG_lex();
int _XLANG_parse();
void _XLANG_error(const char* s);

std::stringstream &errors();
const char* sym_name(uint32 sym_id);
ParseContext* &parse_context();

node::NodeBase* make_ast(Allocator &alloc, FILE* file);

#endif
