class MetamodelX::Implicit-RoleHOW is Metamodel::ClassHOW {
    method new_type(|) {
        my \type = callsame();
        type.HOW.setup_implicit_role(type);
        type
    }

    method setup_implicit_role(Mu \type) {
        Metamodel::Primitives.configure_type_checking(type, [], :call_accepts);
    }

    method accepts_type($obj, $checkee) {
        METHOD: for $obj.^methods.grep({.name ne .name.uc}) -> Method $method {
            my @issues;
            my @candidates = $checkee.can($method.name);
            my $found-one = False;
            my @method-params = $method.signature.params[1..Inf];
            CANDIDATE: for @candidates -> $candidate {
                unless $method.arity == $candidate.arity {
                    @issues.append("Expecting arity {$method.arity}, but got arity {$candidate.arity}");
                    next CANDIDATE;
                }
                unless $candidate.returns.ACCEPTS($method.returns) {
                    @issues.append("Expecting return type {$method.returns.^name}, but got return type {$candidate.returns.^name}");
                    next CANDIDATE;
                };

                my @candidate-params = $candidate.signature.params[1..Inf];
                for @method-params Z @candidate-params -> (Parameter $p1, Parameter $p2) {
                    unless $p1.sigil.ACCEPTS($p2.sigil)
                    and $p1.type.ACCEPTS($p2.type)
                    and $p1.positional !^^ $p2.positional
                    and $p1.slurpy !^^ $p2.slurpy {
                        @issues.append("Problem with Parameter {$p1.name}");
                        next CANDIDATE
                    }

                    unless $p1.positional {
                        unless $p1.name ~~ $p2.name {
                            @issues.append("Expecting Named Parameter {$p1.name}, but got {$p2.name}");
                            next CANDIDATE
                        }
                    }
                }
                $found-one = True;
                last CANDIDATE;
            }
            next METHOD if $found-one;
            return False if $checkee ~~ Iterable|Regex;
            $*ERR.say: "Could not find matching candidate for {$obj.^name} method {$method.name}\n"
                           ~ "{$checkee.^name} does not implement irole {$obj.^name}.";
            if @issues.elems > 0 || @candidates.elems == 0 {
                $*ERR.say: "Issues:";
                if @candidates.elems > 0 {
                for @candidates Z @issues -> ($candidate, $issue) {
                    $*ERR.say: "	{$candidate.name}: $issue";
                }
                } else {
                    $*ERR.say: "	{$checkee.^name} does not implement method {$method.name}."
                }
            }
            return False;
        }
        return True;
    }
}

my package EXPORTHOW {
    package DECLARE {
        constant irole = MetamodelX::Implicit-RoleHOW;
    }
}


=begin pod

=head1 NAME

Role::Implicit - Golang-inspired interfaces

=head1 SYNOPSIS

=begin code :lang<raku>

use Role::Implicit;

irole Greeter {
    method greeting(Str $name --> Str) { ... }
}

class Person {
    method greeting(Str $name --> Str) {
        return "Hello, $name";
    }
}

class Dog {
    has $.name = "Spike";
    method greeting(Str $name --> Str) {
        "$!name licks $name";
    }
}

sub greet(Greeter $greeter) {
    say $greeter.greet("Bob");
}

greet(Dog.new);

greet(Person.new);

# Output:
# "Spike licks Bob"
# "Hello, Bob"

=end code

=head1 DESCRIPTION

Role::Implicit allows creating golang-style implicit roles. Unlike normal roles, no declaration has to
be done to tell raku that a class implements an implicit role.

Implicit roles check the methods available on an object to determine if it can be used in place of an
implicit role. These checks are done at compile-time whenever possible.

=head1 AUTHOR

Travis Gibson <TGib.Travis@protonmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2021 Travis Gibson

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
