package features

import "../algebra"

// Compatibility façade for feature code. Algebra implementation lives in the
// focused modules under src/algebra.
MAX_NODES :: algebra.MAX_NODES
MAX_TOKENS :: algebra.MAX_TOKENS
MAX_MOVES :: algebra.MAX_MOVES
MAX_TERMS :: algebra.MAX_TERMS
LABEL_CAP :: algebra.LABEL_CAP
EQUIVALENCE_NOTE :: algebra.EQUIVALENCE_NOTE
DISTRIBUTIVE_ADDITION_RULE :: algebra.DISTRIBUTIVE_ADDITION_RULE
DISTRIBUTIVE_SUBTRACTION_RULE :: algebra.DISTRIBUTIVE_SUBTRACTION_RULE

Expr_Id :: algebra.Expr_Id
NO_EXPR :: algebra.NO_EXPR
Binary_Op :: algebra.Binary_Op
Num :: algebra.Num
Var :: algebra.Var
Bin :: algebra.Bin
Expr_Node :: algebra.Expr_Node
Equation :: algebra.Equation
Side :: algebra.Side
Label :: algebra.Label

label_set :: algebra.label_set
label_str :: algebra.label_str
format_equation :: algebra.format_equation
format_side :: algebra.format_side

Parse_Error :: algebra.Parse_Error
parse_equation :: algebra.parse_equation
Source_Token_Kind :: algebra.Source_Token_Kind
Source_Span :: algebra.Source_Span
Source_Token :: algebra.Source_Token
Source_Token_List :: algebra.Source_Token_List
lex_source :: algebra.lex_source

Token_Kind :: algebra.Token_Kind
Token :: algebra.Token
Token_List :: algebra.Token_List
tokenize :: algebra.tokenize

Move_Kind :: algebra.Move_Kind
Term :: algebra.Term
Move :: algebra.Move
Move_List :: algebra.Move_List
valid_moves_by_expr :: algebra.valid_moves_by_expr
valid_moves_by_token :: algebra.valid_moves_by_token
valid_moves :: algebra.valid_moves
apply_move :: algebra.apply_move

Move_View :: algebra.Move_View
describe_move :: algebra.describe_move
explain_move :: algebra.explain_move
is_solved :: algebra.is_solved
Move_Animation_Pair :: algebra.Move_Animation_Pair
Move_Animation_Map :: algebra.Move_Animation_Map
move_animation_map :: algebra.move_animation_map
