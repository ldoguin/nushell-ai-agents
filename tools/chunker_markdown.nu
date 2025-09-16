# A pure Nushell Markdown chunker that emulates LangChainJS's MarkdownTextSplitter:
# - Prefers splitting on Markdown structure (headings, code fences, horizontal rules, blank lines, list starts)
# - Keeps fenced code blocks intact
# - Enforces chunk_size with character-overlap fallback
# - Emits JSON records {content, meta:{headers, start_line, end_line}}
#
# Usage:
#   open README.md | markdown-chunker --chunk-size 1200 --overlap 200
#   (or) markdown-chunker -t (open README.md | into string)
#
# Notes:
# - Input can come from stdin or --text
# - chunk_size counts characters (like LangChain’s default)
# - overlap is applied in characters across emitted chunks
export def markdown-chunker [
  --chunk-size: int = 1000 # Chunk size in chars
  --overlap: int = 200 # overlap in chars
  --text (-t): string  # optional: pass text directly; otherwise read from stdin
] {

  # --- read the source text ---
  let src = if ($text | is-empty) { $in | into string } else { $text }
  if ($src | is-empty) { return [] }

  let lines = ($src | split row "\n")

  # helpers ---------------
  def is_heading [line: string] { $line =~ '^#{1,6}\s' }
  def is_hrule   [line: string] { $line =~ '^(\*\s*\*\s*\*|-{3,}|_{3,})\s*$' }
  def is_list    [line: string] { $line =~ '^\s*([-*+]\s+|\d+\.\s+)' }
  def is_blank   [line: string] { $line =~ '^\s*$' }
  def is_fence   [line: string] { $line =~ '^\s*(```|~~~)' }

  # substring last N chars
  def tail-chars [s: string, n: int] {
    let L = ($s | str length )
    if $n <= 0 or $L == 0 { "" } else {
      let start = (if $n >= $L { 0 } else { $L - $n })
      $s | str substring ($start)..
    }
  }

  # ---------- scan lines and build chunks ----------
  mut in_fence = false
  mut fence_marker = ""
  mut buffer = ""
  mut buffer_len = 0
  mut last_good = 0            # last preferred split idx within buffer
  mut last_good_line = 0       # line number for meta
  mut current_headers = {}     # e.g. {h1:"...", h2:"..."}
  mut current_start_line = 1   # 1-based
  mut out = []

  mut i = 0
  while $i < ($lines | length) {
    let line = ($lines | get $i)

    # detect fence boundaries first (we never split inside a fence)
    if (is_fence $line) {
      if not $in_fence {
        $in_fence = true
        $fence_marker = ($line | str trim)
        # this is also a nice split candidate (start of a code block)
        $last_good = $buffer_len
        $last_good_line = ($i + 1)
      } else {
        # closing fence
        $in_fence = false
        $fence_marker = ""
        # boundary after fence is a good split candidate
        # mark after we append the closing line below
      }
    }

    # update header stack if we see a heading (only outside fences)
    if (not $in_fence) and (is_heading $line) {
      # split heading level & text
      let level = ($line | str replace -r '^(\#{1,6}).*$' '$1' | str length )
      let text  = ($line | str replace -r '^#{1,6}\s*' '' | str trim)
      # mutate current_headers to keep a hierarchical path
      mut headers = $current_headers
      # drop deeper levels
      mut k = 1
      mut h = {}
      while $k <= 6 {
        if $k < $level {
          let key = $"h($k)"
          if ($headers | columns | any {|c| $c == $key}) {
            $h = ($h | insert $key ($headers | get $key))
          }
        } else if $k == $level {
          $h = ($h | insert $"h($k)" $text)
        }
        $k = $k + 1
      }
      $current_headers = $h

      # a heading line itself is a great split point BEFORE the heading
      $last_good = $buffer_len
      $last_good_line = ($i)
    }

    # prefer split points (outside fences): hrules, blank lines, list starts
    if (not $in_fence) and ((is_hrule $line) or (is_blank $line) or (is_list $line)) {
      $last_good = $buffer_len
      $last_good_line = ($i + 1)
    }

    # append the line (preserve newline)
    let with_nl = ($line + "\n")
    $buffer = ($buffer + $with_nl)
    $buffer_len = ($buffer_len + ($with_nl | str length))

    # If we just closed a fence, mark a split candidate *after* this line
    if (is_fence $line) and (not $in_fence) {
      $last_good = $buffer_len
      $last_good_line = ($i + 1)
    }

    # enforce chunk_size
    if $buffer_len >= $chunk_size {
      let split_at = (if $last_good > 0 { $last_good } else { $chunk_size })
      let chunk = ($buffer | str substring ..($split_at) | str trim -r)

      if not ($chunk | is-empty) {
        let end_line = $last_good_line
        $out ++= [{
          content: $chunk
          meta: {
            headers: $current_headers
            start_line: $current_start_line
            end_line: (if $end_line > 0 { $end_line } else { $i + 1 })
          }
        }]
      }

      # prepare next buffer with overlap
      let overlap_tail = (tail-chars $chunk $overlap)
      let remainder = ($buffer | str substring ($split_at).. )
      $buffer = ($overlap_tail + $remainder)
      $buffer_len = ($buffer | str length)

      # next chunk starts where we split, but account for overlap (line-wise best effort)
      $current_start_line = (if $last_good_line > 0 { $last_good_line + 1 } else { $i + 1 })
      $last_good = 0
      $last_good_line = 0
    }

    $i = $i + 1
  }

  # flush remainder
  let final_chunk = ($buffer | str trim -r)
  if not ($final_chunk | is-empty) {
    $out ++= [{
      content: $final_chunk
      meta: {
        headers: $current_headers
        start_line: $current_start_line
        end_line: ($lines | length)
      }
    }]
  }

  $out
}