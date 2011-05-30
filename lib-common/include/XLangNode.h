// Variations of a Flex-Bison parser -- based on
// "A COMPACT GUIDE TO LEX & YACC" by Tom Niemann
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

#ifndef XLANG_NODE_H_
#define XLANG_NODE_H_

#include "XLangNodeBase.h" // Node
#include "XLangType.h" // uint32
#include <string> // std::string
#include <vector> // std::vector
#include <stdarg.h> // va_list

namespace node {

class Node : public NodeBase
{
protected:
    NodeBase::type_e m_type;
    uint32 m_sym_id;

public:
    Node(NodeBase::type_e _type, uint32 _sym_id)
        : m_type(_type), m_sym_id(_sym_id)
    {
    }
    NodeBase::type_e type() const
    {
        return m_type;
    }
    uint32 sym_id() const
    {
        return m_sym_id;
    }
};

template<class T>
class LeafNode : virtual public Node, public LeafNodeBase<T>
{
    T m_value;

public:
    LeafNode(uint32 sym_id, T _value)
        : Node(static_cast<NodeBase::type_e>(
              NodeTypeSelector<T>::type), sym_id), m_value(_value)
    {
    }
    T value() const
    {
        return m_value;
    }
};

class InnerNode : virtual public Node, public InnerNodeBase
{
    std::vector<NodeBase*> m_child_vec;

public:
    InnerNode(uint32 sym_id, size_t _child_count, va_list ap)
        : Node(NodeBase::INNER, sym_id)
    {
        m_child_vec.resize(_child_count);
        for(size_t i = 0; i<_child_count; i++)
            m_child_vec[i] = va_arg(ap, NodeBase*);
    }
    NodeBase* child(uint32 index) const
    {
        return m_child_vec[index];
    }
    size_t child_count() const
    {
        return m_child_vec.size();
    }
};

}

#endif
