# https://gist.github.com/april/ee2e104b1435f3113e67663d8875bbef

git-log-json() {
  local Q=$'\x01'-$RANDOM-$(date +%s)
  local FORMAT=--pretty=format:"{${Q}author${Q}:{${Q}name${Q}:${Q}%aN${Q},${Q}email${Q}:${Q}%aE${Q},${Q}date${Q}:${Q}%aD${Q},${Q}dateISO8601${Q}:${Q}%aI${Q}},${Q}body${Q}:${Q}%b${Q},${Q}commitHash${Q}:${Q}%H${Q},${Q}commitHashAbbreviated${Q}:${Q}%h${Q},${Q}committer${Q}:{${Q}name${Q}:${Q}%cN${Q},${Q}email${Q}:${Q}%cE${Q},${Q}date${Q}:${Q}%cD${Q},${Q}dateISO8601${Q}:${Q}%cI${Q}},${Q}encoding${Q}:${Q}%e${Q},${Q}notes${Q}:${Q}%N${Q},${Q}parent${Q}:${Q}%P${Q},${Q}parentAbbreviated${Q}:${Q}%p${Q},${Q}refs${Q}:${Q}%D${Q},${Q}signature${Q}:{${Q}key${Q}:${Q}%GK${Q},${Q}signer${Q}:${Q}%GS${Q},${Q}verificationFlag${Q}:${Q}%G?${Q}},${Q}subject${Q}:${Q}%s${Q},${Q}subjectSanitized${Q}:${Q}%f${Q},${Q}tree${Q}:${Q}%T${Q},${Q}treeAbbreviated${Q}:${Q}%t${Q}},"

  git log "$FORMAT" $1 | \
    (
      echo -n '['
      sed -e ':a' -e 'N' -e '$!ba' \
        -e 's/,$//' \
        -e 's/'$Q'},\n{'$Q'/'$Q'},{'$Q'/g' \
        -e 's/\\/\\\\/g' \
        -e 's/\r//g' \
        -e 's/\n/\\n/g' \
        -e 's/\t/\\t/g' \
        -e 's/"/\\"/g' \
        -e 's/'$Q'/"/g'
      echo ']'
    )
}
