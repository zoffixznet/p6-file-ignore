use MONKEY-SEE-NO-EVAL;

class File::Ignore {
    class Rule {
        grammar Parser {
            token TOP {
                [ $<leading>='/' ]?
                <path-part>+ % '/'
                [ $<trailing>='/' ]?
            }

            token path-part {
                <matcher>+
            }

            proto token matcher    { * }
            token matcher:sym<*>   { <sym> }
            token matcher:sym<lit> { <-[/*]>+ }
        }

        class RuleCompiler {
            method TOP($/) {
                make Rule.new(
                    pattern => EVAL('/' ~
                                    ($<leading> ?? '^' !! '') ~
                                    $<path-part>.map(*.ast).join(" '/' ")  ~
                                    '<?before "/" | $> /'),
                    directory-only => ?$<trailing>
                );
            }

            method path-part($/) {
                make $<matcher>.map(*.ast).join(' ');
            }

            method matcher:sym<*>($/) {
                make '<-[/]>*';
            }

            method matcher:sym<lit>($/) {
                make "'$/.subst('\\', '\\\\', :g).subst('\'', '\\\'', :g)'";
            }
        }

        has Regex $.pattern;
        has Bool $.directory-only;

        method parse(Str() $rule) {
            with Parser.parse($rule, :actions(RuleCompiler)) {
                .ast;
            }
            else {
                die "Could not parse ignore rule $rule";
            }
        }
    }

    has Rule @!rules;

    submethod BUILD(:@rules!) {
        @!rules = @rules.map({ Rule.parse($_) });
    }

    method parse(Str() $ignore-spec) {
        File::Ignore.new(rules => $ignore-spec.lines.grep(* !~~ /^ [ '#' | \s*$ ]/))
    }

    method ignore-file(Str() $path) {
        for @!rules {
            next if .directory-only;
            return True if .pattern.ACCEPTS($path);
        }
        False
    }

    method ignore-directory(Str() $path) {
        for @!rules {
            return True if .pattern.ACCEPTS($path);
        }
        False
    }
}
