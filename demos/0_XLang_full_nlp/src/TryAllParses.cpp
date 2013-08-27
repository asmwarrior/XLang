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

#include "TryAllParses.h"
#include "XLang.h"
#include "node/XLangNodeIFace.h" // node::NodeIdentIFace
#include "XLang.tab.h" // ID_XXX (yacc generated)
#include "XLangAlloc.h" // Allocator
#include "XLangString.h" // xl::tokenize
#include "XLangSystem.h" // xl::system::shell_capture
#include <vector> // std::vector
#include <stack> // std::stack
#include <map> // std::map
#include <string> // std::string
#include <iostream> // std::cout

void permute_lexer_id_map(
        std::map<std::string, std::vector<uint32_t>>* lexer_id_maps,
        std::map<std::string, uint32_t>*              lexer_id_map)
{
    if(!lexer_id_maps || !lexer_id_map)
        return;
    (*lexer_id_map)["and"]  = ID_CONJ;
    (*lexer_id_map)["and2"] = ID_CONJ_2;
    (*lexer_id_map)["and3"] = ID_CONJ_3;
}

void build_pos_permutations(
        std::list<std::vector<int>>           &pos_permutations,           // OUT
        std::vector<std::vector<std::string>> &sentence_pos_options_table, // IN
        std::stack<int>                       &sentence_pos_indices,       // TEMP
        int                                    word_index)                 // TEMP
{
    if(static_cast<size_t>(word_index) >= sentence_pos_options_table.size())
    {
        size_t n = sentence_pos_indices.size();
        std::vector<int> pos_permutation(n);
        for(int i = 0; i < static_cast<int>(n); i++)
        {
            pos_permutation[n-i-1] = sentence_pos_indices.top();
            sentence_pos_indices.pop();
        }
        pos_permutations.push_back(pos_permutation);
        for(auto q = pos_permutation.begin(); q != pos_permutation.end(); q++)
            sentence_pos_indices.push(*q);
        return;
    }
    std::vector<std::string> &word_pos_options = sentence_pos_options_table[word_index];
    int pos_index = 0;
    for(auto p = word_pos_options.begin(); p != word_pos_options.end(); p++)
    {
        sentence_pos_indices.push(pos_index);
        build_pos_permutations(
                pos_permutations,
                sentence_pos_options_table,
                sentence_pos_indices,
                word_index+1);
        sentence_pos_indices.pop();
        pos_index++;
    }
}

void build_pos_permutations(
        std::list<std::vector<int>>           &pos_permutations,           // OUT
        std::vector<std::vector<std::string>> &sentence_pos_options_table) // IN
{
    std::stack<int> sentence_pos_indices;
    int word_index = 0;
    build_pos_permutations(
            pos_permutations,
            sentence_pos_options_table,
            sentence_pos_indices,
            word_index);
}

bool get_wordnet_pos(std::string word, std::vector<std::string> &word_pos)
{
    if(word.empty())
        return false;
    if(
        word == "for" ||
        word == "and" ||
        word == "nor" ||
        word == "but" ||
        word == "or"  ||
        word == "yet" ||
        word == "so")
    {
        word_pos.push_back("Conj");
        return true;
    }
    if(
        word == "to"   ||
        word == "from" ||
        word == "of")
    {
        word_pos.push_back("Prep");
        return true;
    }
    std::string output_which_wn = xl::system::shell_capture("which wn");
    if(output_which_wn.empty())
    {
        std::cerr << "wordnet not found" << std::endl;
        return false;
    }
    const char* wn_faml_types[] = {"n", "v", "a", "r"};
    const char* pos_types[] = {"N", "V", "Adj", "Adv"};
    bool found_match = false;
    for(int i = 0; i<4; i++)
    {
        std::string output_wn_famlx = xl::system::shell_capture("wn \"" + word + "\" -faml" + wn_faml_types[i]);
        if(output_wn_famlx.size())
        {
            word_pos.push_back(pos_types[i]);
            found_match = true;
        }
    }
    return found_match;
}

void test_build_pos_permutations()
{
    test_build_pos_permutations("eats shoots and leaves");
    //test_build_pos_permutations("flying saucers are dangerous");
}

void test_build_pos_permutations(std::string sentence)
{
    // prepare input
    std::vector<std::vector<std::string>> sentence_pos_options_table;

    std::vector<std::string> words = xl::tokenize(sentence);
    sentence_pos_options_table.resize(words.size());
    int word_index = 0;
    for(auto t = words.begin(); t != words.end(); t++)
    {
        std::string word = *t;
        std::cout << word << "<";
        std::vector<std::string> word_pos;
        get_wordnet_pos(word, word_pos);
        for(auto r = word_pos.begin(); r != word_pos.end(); r++)
        {
            std::string pos = *r;
            sentence_pos_options_table[word_index].push_back(pos);
            std::cout << pos << " ";
        }
        std::cout << ">" << std::endl;
        word_index++;
    }
//    return;

//    // eats shoots and leaves
//    // V    V      C   V
//    //      N          N
//    sentence_pos_options_table.resize(4);
//    sentence_pos_options_table[0].push_back("V");
//    sentence_pos_options_table[1].push_back("V");
//    sentence_pos_options_table[1].push_back("N");
//    sentence_pos_options_table[2].push_back("C");
//    sentence_pos_options_table[3].push_back("V");
//    sentence_pos_options_table[3].push_back("N");

//    // flying saucers are dangerous
//    // Adj    N       Aux Adj
//    // V
//    sentence_pos_options_table.resize(4);
//    sentence_pos_options_table[0].push_back("Adj");
//    sentence_pos_options_table[0].push_back("V");
//    sentence_pos_options_table[1].push_back("N");
//    sentence_pos_options_table[2].push_back("Aux");
//    sentence_pos_options_table[3].push_back("Adj");

    // run
    std::list<std::vector<int>> pos_permutations;
    build_pos_permutations(pos_permutations, sentence_pos_options_table);

    // print results
    int permutation_index = 0;
    for(auto p = pos_permutations.begin(); p != pos_permutations.end(); p++)
    {
        std::cout << "permutation #" << permutation_index << ": ";
        int word_index = 0;
        auto pos_permutation = *p;
        for(auto q = pos_permutation.begin(); q != pos_permutation.end(); q++)
        {
            int pos_index = *q;
            std::string pos_option = sentence_pos_options_table[word_index][pos_index];
            word_index++;
            std::cout << pos_option << " ";
        }
        std::cout << std::endl;
        permutation_index++;
    }
}
