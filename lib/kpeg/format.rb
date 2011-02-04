require 'kpeg'

module KPeg
  FORMAT = KPeg.grammar do |g|
    g.sp = g.kleene " "
    g.var = g.any("-", /[a-zA-Z][-_a-zA-Z0-9]*/)
    g.var_ref = g.seq(:var) { |x| ref(x) }

    g.dbl_escape_quote = g.str('\"') { '"' }
    g.dbl_not_quote = g.many(g.any(:dbl_escape_quote, /[^"]/)) { |*a| a.join }
    g.dbl_string = g.seq('"', g.t(:dbl_not_quote, "str"), '"') { |x| str(x) }

    g.sgl_escape_quote = g.str("\\'") { "'" }
    g.sgl_not_quote = g.many(g.any(:sgl_escape_quote, /[^']/)) { |*a| a.join }
    g.sgl_string = g.seq("'", g.t(:sgl_not_quote, "str"), "'") { |x| str(x) }

    g.string = g.any(:dbl_string, :sgl_string)

    g.not_slash = g.many(g.any('\/', %r![^/]!)) { |*a| a.join }
    g.regexp = g.seq('/', :not_slash, '/') { |_,x,_| reg(Regexp.new(x)) }

    g.char = /[a-zA-Z0-9]/
    g.char_range = g.seq('[', g.t(:char, "l"), '-', g.t(:char, "r"), ']') {
                     |l,r| range(l, r)
                   }

    g.range_elem = /([1-9][0-9]*)|\*/
    g.mult_range = g.seq('[', :sp, g.t(:range_elem, "l"), :sp, ',', 
                              :sp, g.t(:range_elem, "r"), :sp, ']') {
                                  |a,b|
                                  [a == "*" ? nil : a.to_i,
                                   b == "*" ? nil : b.to_i]
                   }

    g.curly_block = g.seq(:curly) { |a| Array(a[1]).join }
    g.curly = g.seq("{", g.kleene(g.any(/[^{}]+/, :curly)), "}")

    g.spaces = g.kleene(" ")

    g.value = g.seq(:value, ":", :var) { |a,_,b| t(a,b) } \
            | g.seq(:value, "?") { |v,_| maybe(v) }   \
            | g.seq(:value, "+") { |v,_| many(v) }    \
            | g.seq(:value, "*") { |v,_| kleene(v)  } \
            | g.seq(:value, :mult_range) { |v,r| multiple(v, *r) } \
            | g.seq("&", :value) { |_,v| andp(v) } \
            | g.seq("!", :value) { |_,v| notp(v) } \
            | g.seq(:value, :spaces, :value) { |a,_,b| seq(a, b) } \
            | g.seq("(", g.t(:outer, "o"), ")") { |o| o } \
            | g.seq(:curly_block) { |a| action(a) } \
            | g.char_range | g.regexp | g.string | g.var_ref

    g.bsp = g.kleene g.any(" ", "\n")

    g.choose_cont = g.seq(:bsp, "|", :bsp, g.t(:value, "v")) { |x| x }
    g.outer = g.seq(:value, g.many(:choose_cont)) {
                |a,b| b.kind_of?(Array) ? any(a, *b) : any(a, b)
              } \
            | g.value

    g.assignment = g.seq(:sp, g.t(:var, "v"), :sp, "=", :sp, g.t(:outer, "o")) {
                     |v,e| set(v, e); [:set, v, e]
                   }

    g.assignments = g.seq(:assignment, g.maybe([:sp, "\n", :assignments])) {
                      |a,b| b.empty? ? a : [:rules, a, b.last]
                    }
    g.root = g.seq(:assignments, :sp, g.maybe("\n")) { |a,_,_| a }
  end
end
