/* vim: set syntax=lex: */
/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int nested_comment();
%}

/*
 * Define names for regular expressions here.
 */

DIGIT		[0-9]
ID		[a-zA-Z0-9_]*
TYPEID		[A-Z]{ID}
OBJID		[a-z]{ID}
NEST_COMMENT	\(\*
NEST_COMMENT_END \*\)
COMMENT		--

/*
 * Multichar operators
 */
DARROW          =>
ASSIGN		\<\-
LE		\<=

/*
 * WS, excluding newline
 */
WHITESPACE	[\t\b\f\r\v ]

/*
 * Keywords
 */
CLASS		[cC][lL][aA][sS]{2}
ELSE		[eE][lL][sS][eE]
FI		[fF][iI]
IF		[iI][fF]
IN		[iI][nN]
INHERITS	[iI][nN][hH][eE][rR][iI][tT][sS]
LET		[lL][eE][tT]
LOOP		[lL][oO]{2}[pP]
POOL		[pP][oO]{2}[lL]
THEN		[tT][hH][eE][nN]
WHILE		[wW][hH][iI][lL][eE]
CASE		[cC][aA][sS][eE]
ESAC		[eE][sS][aA][cC]
OF		[oO][fF]
NEW		[nN][eE][wW]
ISVOID		[iI][sS][vV][oO][iI][dD]
NOT		[nN][oO][tT]
TRUE		t[rR][uU][eE]
FALSE		f[aA][lL][sS][eE]


SINGLE_CHAR_TOK	[{}\(\):\.,+/\-*/~<=;@]

%%

 /*
  *  Nested comments
  */
{NEST_COMMENT}	{
			int r = nested_comment();
			if (r == -1) {
				cool_yylval.error_msg = "EOF in comment";
				return (ERROR);
			}
		}

{NEST_COMMENT_END}	{
				cool_yylval.error_msg = "Unmatched *)";
				return (ERROR);
			}

{COMMENT}	{
			char c;
			// eat until EOF or newline
			while (true) {
				c = yyinput();
				if (c == EOF) {
					break;
				}
				if (c == '\n') {
					unput(c);
					break;
				}
			}

		}


 /*
  *  The multiple-character operators.
  */
{DARROW}	{ return (DARROW); }
{ASSIGN}	{ return (ASSIGN); }
{LE}		{ return (LE); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
{DIGIT}+	{
			cool_yylval.symbol = inttable.add_string(yytext);
			return (INT_CONST);
		}


{CLASS}		{ return (CLASS); }
{ELSE}		{ return (ELSE); }
{FI}		{ return (FI); }
{IF}		{ return (IF); }
{IN}		{ return (IN); }
{INHERITS}	{ return (INHERITS); }
{LET}		{ return (LET); }
{LOOP} 		{ return (LOOP); }
{POOL}		{ return (POOL); }
{THEN}		{ return (THEN); }
{WHILE}		{ return (WHILE); }
{CASE}		{ return (CASE); }
{ESAC}		{ return (ESAC); }
{OF}		{ return (OF); }
{NEW}		{ return (NEW); }
{ISVOID}	{ return (ISVOID); }
{NOT}		{ return (NOT); }

{TRUE}		{
			cool_yylval.boolean = true;
			return (BOOL_CONST);
		}

{FALSE} 	{
			cool_yylval.boolean = false;
			return (BOOL_CONST);
		}



{TYPEID}	{
			cool_yylval.symbol = stringtable.add_string(yytext);
			return (TYPEID);
		}

{OBJID}		{
			cool_yylval.symbol = stringtable.add_string(yytext);
			return (OBJECTID);
		}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */
\"	{
		string_buf_ptr = string_buf;
		char c;
		while (true) {
			c = yyinput();
			// Encountered null character or string too long
			if (c == 0 || (string_buf_ptr == &string_buf[MAX_STR_CONST])) {
				if (c == 0) {
					cool_yylval.error_msg = "String contains null character";
				} else {
					cool_yylval.error_msg = "String constant too long";
				}
				char prev = -1;
				// find the first thing: unescaped newline or closing \"
				while (c != EOF) {
					if (c == '\n') {
						// stop if this newline wasn't escaped
						if (prev != -1 && prev != '\\') {
							unput(c);
							break;
						} else {
							++curr_lineno;
						}
					} else if (c == '\"') {
						break;
					}
					prev = c;
					c = yyinput();
				}
				return (ERROR);
			}

			// deal with escaped characters
			if (c == '\\') {
				char c1 = yyinput();
				switch (c1) {
				default:
					*string_buf_ptr++ = c1;
					break;
				case 'n':
					*string_buf_ptr++ = '\n';
					break;
				case 'b':
					*string_buf_ptr++ = '\b';
					break;
				case 't':
					*string_buf_ptr++ = '\t';
					break;
				case 'f':
					*string_buf_ptr++ = '\f';
					break;
				case '\n':
					*string_buf_ptr++ = '\n';
					++curr_lineno;
					break;
				case '\0':
					// escaped null. unput() and catch it again in next iteration so we can deal with it properly.
					unput(c1);
					break;
				}
			} else if (c == '\n') {
				curr_lineno++;
				cool_yylval.error_msg = "Unterminated string constant";
				return (ERROR);
			} else if (c == EOF) {
				cool_yylval.error_msg = "EOF in string constant";
				return (ERROR);
			} else if (c == '\"') {
				break;
			} else {
				*string_buf_ptr = c;
				++string_buf_ptr;
			}
		}

		*string_buf_ptr = '\0';
		cool_yylval.symbol = stringtable.add_string(string_buf);
		return (STR_CONST);

	}

\n	{
		++curr_lineno;
	}

{WHITESPACE}+	;

{SINGLE_CHAR_TOK}	{
				return (int)yytext[0];
			}

.	{
		cool_yylval.error_msg = stringtable.add_string(yytext)->get_string();
		return (ERROR);
	}

%%

/*
 * Eat a nested comment.
 * returns 0 if no errors, -1 if EOF encountered while eating.
 */
int nested_comment() {
	char c;
	while (true) {
		c = yyinput();
		if (c == '*') {
			char c1 = yyinput();
			if (c1 == ')') {
				return 0;
			} else {
				unput(c1);
			}
		} else if (c == '(') {
			char c1 = yyinput();
			if (c1 == '*') {
				// encountered a nested (*, recurse
				nested_comment();
			} else {
				unput(c1);
			}
		} else if (c == EOF) {
			return -1;
		} else if (c == '\\') {
			// eat the escaped char
			yyinput();
		} else if (c == '\n') {
			++curr_lineno;
		}
	}
	return 0;
}
