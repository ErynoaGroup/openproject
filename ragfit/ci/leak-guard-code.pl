#!/usr/bin/env perl
# Leak guard helper: neutralizes an at sign followed by an identifier ONLY in code position of code files, so Ruby instance and
# class variables and JS decorators are not reported as mentions. Comments (# , //,
# /* */, <%# %>), string literals and ERB text outside <% %> are passed through unchanged and stay
# mention-checked. Line based and deliberately simple (no heredocs, %-literals or regex literals): anything
# it cannot classify stays as it is, so it errs towards reporting.
# Usage: leak-guard-code.pl ruby|js|erb   (stdin -> stdout)
use strict;
use warnings;
my $mode = shift // '';
die "usage: $0 ruby|js|erb\n" unless $mode =~ /^(ruby|js|erb)$/;
my $js_block = 0;    # inside /* ... */ across lines
my $erb_in = 0;      # inside <% ... %> across lines
my $erb_comment = 0; # inside <%# ... %>

sub code {
  my ($s, $lang) = @_;
  my ($o, $q, $i, $n) = ('', '', 0, length $s);
  while ($i < $n) {
    my $c = substr($s, $i, 1);
    my $two = substr($s, $i, 2);
    if ($lang eq 'js' && $js_block) {
      if ($two eq '*/') { $js_block = 0; $o .= '*/'; $i += 2; next; }
      $o .= $c; $i++; next;
    }
    if ($q) {                                   # string literal: unchanged, except Ruby "#{...}"
      if ($c eq '\\') { $o .= substr($s, $i, 2); $i += 2; next; }
      if ($lang eq 'ruby' && $q eq '"' && $two eq '#{') {
        my $j = index($s, '}', $i + 2);
        $j = $n if $j < 0;
        $o .= '#{' . code(substr($s, $i + 2, $j - $i - 2), $lang) . ($j < $n ? '}' : '');
        $i = $j + 1; next;
      }
      $q = '' if $c eq $q;
      $o .= $c; $i++; next;
    }
    if ($c eq '"' || $c eq "'" || $c eq '`') { $q = $c; $o .= $c; $i++; next; }
    if ($lang eq 'ruby' && $c eq '#') { $o .= substr($s, $i); last; }        # comment: unchanged
    if ($lang eq 'js' && $two eq '//') { $o .= substr($s, $i); last; }
    if ($lang eq 'js' && $two eq '/*') { $js_block = 1; $o .= '/*'; $i += 2; next; }
    if ($c eq '@' && substr($s, $i + 1) =~ /^\@?[A-Za-z_]/) {
      my $at = substr($s, $i + 1, 1) eq '@' ? 2 : 1;
      $o .= '_at_' x $at; $i += $at; next;
    }
    $o .= $c; $i++;
  }
  return $o;
}

sub erb {
  my ($l) = @_;
  my $o = '';
  while (length $l) {
    if ($erb_in) {
      if ($l =~ s/^(.*?)%>//s) { $o .= ($erb_comment ? $1 : code($1, 'ruby')) . '%>'; $erb_in = 0; }
      else { $o .= $erb_comment ? $l : code($l, 'ruby'); $l = ''; }
    } elsif ($l =~ s/^(.*?)<%(%?)([#=-]?)//s) {
      $o .= "$1<%$2$3";
      if ($2 eq '') { $erb_in = 1; $erb_comment = $3 eq '#'; }               # '<%%' is literal text
    } else { $o .= $l; $l = ''; }
  }
  return $o;
}

while (my $l = <STDIN>) {
  chomp $l;
  if ($mode eq 'erb') { print erb($l), "\n"; next; }
  if ($mode eq 'js' && !$js_block && $l =~ /^\s*\*/) { print "$l\n"; next; }  # JSDoc continuation line
  print code($l, $mode), "\n";
}
