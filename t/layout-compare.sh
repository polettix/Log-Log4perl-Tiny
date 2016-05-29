#!/bin/bash

[ -n "$AUTHOR_TESTING" ] || AUTHOR_TESTING=0
if [ "$AUTHOR_TESTING" -eq 0 ] ; then
   echo "1..0 # Skipped: AUTHOR_TESTING not set"
   exit 0
fi

ME=$(readlink -f "$0")
MD=$(dirname "$ME")
LOCAL_PERL5LIB="$MD:$MD/../lib:$MD/../local/lib/perl5"
export PERL5LIB="$LOCAL_PERL5LIB:$PERL5LIB"

if ! perl -MLog::Log4perl -e 0 >/dev/null 2>&1 ; then
   echo "1..0 # Skipped: Log::Log4perl not installed"
   exit 0
fi

module_path() {
   perldoc -l "$1" | sed -e 's/pod$/pm/'
}

# thin wrapper around compare.pl. Transform CODE references' addresses
# into a specific constant string, so that it does not get in the way of
# the comparison
invoke_compare() {
   local module=$1
   local expander=$2

   perl "$MD/layout-compare.pl" "$module" "$expander" 2>&1 >/dev/null \
      | sed 's/CODE(0x[0-9a-fA-F]*)/CODE(0xWHATEVER)/g'
}

echo "1..6"

LL=$(module_path Log::Log4perl)
LLT=$(module_path Log::Log4perl::Tiny)
echo '# comparing Log::Log4perl to Log::Log4perl::Tiny about caller()'
echo "#   Log::Log4perl      -> $LL"
echo "#   Log::Log4perl:Tiny -> $LLT"

count=0
for expander in C F l L M T ; do
   count=$((count + 1))
   invoke_compare 'Log::Log4perl'       "$expander" >sample-output-main.txt
   invoke_compare 'Log::Log4perl::Tiny' "$expander" >sample-output-tiny.txt

   diff -u sample-output-main.txt sample-output-tiny.txt

   if [ "$?" -eq 0 ] ; then
      echo "ok $count - $expander expander"
   else
      echo "not ok $count - $expander expander"
   fi
done

rm sample-output-main.txt sample-output-tiny.txt
