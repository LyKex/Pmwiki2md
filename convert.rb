
def pm2md(pm_dir, filename, pages)
  text = File.read("#{pm_dir}/#{filename}")

  # preformatted text (eg. code block) is not touched
  lines = text.split("\n")
  codes = []
  iscode = false
  for row in 0..lines.length-1
    if lines[row].start_with?(" ") or (iscode and lines[row].empty?)
      iscode = true
      codes.push(lines[row])
      lines[row] = "XXXCODEBLOCKXXX"
    else
      iscode = false
    end
  end
  text = lines.join("\n")

  tab = "  "
  # remove unsupported format
  # text.gsub!()
  # bullet points
  text.gsub!(/^(\h*)(\*+) ?(.*)/) { |t| space = " " * $1.length; indent = tab * ($2.length - 1); space + indent + "- " + $3}
  # order list
  text.gsub!(/^(\h*)(#+) ?(.*)/) { |t| indent = tab * ($2.length-1); indent + "1. " + $3}
  # blockquotes
  # assumes each line of a blockquote in PmWiki is started with "->".
  text.gsub!(/^->\s*(.*)/, '> \1')

  # headings
  text.gsub!(/^(!{1,6})\s*(.*)/) { "#"*$1.length + " " + $2.strip}
  # italics
  text.gsub!(/(?<!')'{2}([^']+)'{2}(?!')/) {"*" + $1.strip + "*"}
  # bold
  text.gsub!(/(?<!')'{3}([^']+)'{3}(?!')/) {"**" + $1.strip + "**"}
  # bold italics
  text.gsub!(/(?<!')'{4}([^']+)'{4}(?!')/) {"***" + $1.strip + "***"}
  # monospace [@..@] and @@..@@ into inline monospace
  text.gsub!(/(?<!\[)\[\@{1}([^\]\@]+)\@{1}\](?!\])/) {"`" + $1.strip + "`"}
  text.gsub!(/(?<!\[)\@{2}([^\]\@]+)\@{2}(?!\])/) {"`" + $1.strip + "`"}
  # text.gsub!(/(?<!\[)\@{1}([^\]\@]+)\@{1}(?!\])/) {"`" + $1.strip + "`"}
  # large text
  # TODO potentially match across multiple [+ +]
  # text.gsub!(/\[\+([^\]]*)\+\]/) { "## " + $1 } 
  # text.gsub!(/\[\+(.*)\+\]/) { "## " + $1 } 
  text.gsub!(/\[(?<!\+)\+{1}([^\+]+)\+{1}(?!\+)\]/) {"## " + $1 }
  # larger text
  text.gsub!(/\[(?<!\+)\+{2}([^\+]+)\+{2}(?!\+)\]/) {"# " + $1 }
  # text.gsub!(/\[\+\+(.*)\+\+\]/) { "# " + $1 } 
  # small text
  # TODO no equivalent styling in md
  text.gsub!(/\[-([^\]]*)-\]/) { $1 } 
  # smaller text
  # TODO no equivalent styling in md
  text.gsub!(/\[--([^\]]*)--\]/) { $1 } 
  # strike through
  text.gsub!(/\{-([^\}]*)-\}/) {"~~" + $1.strip + "~~"} 
  # underscore
  # TODO no equivalent styling in md
  text.gsub!(/\{\+([^\}]*)\+\}/) { "_" + $1.strip + "_" } 
  # subscript
  text.gsub!(/\'\_([^\']*)\_\'/) { "<sub>" + $1.strip + "</sub>"} 
  # superscript
  text.gsub!(/\'\^([^\']*)\^\'/) { "<sup>" + $1.strip + "</sup>"} 

  # join line
  text.gsub!(/(?<!\\)\\{1}$/, '')
  # force linebreak
  text.gsub!(/(?<!\\)\\{2}$/, "\\")
  # force two linebreak
  text.gsub!(/(?<!\\)\\{3}$/, "\n\n")

  
  # single word color
  text.gsub!(/%red%([^%]+)/) {"<span style=\"color: red;\">%s</span>" % $1}
  text.gsub!(/%blue%([^%]+)/) {"<span style=\"color: blue;\">%s</span>" % $1}
  text.gsub!(/%green%([^%]+)/) {"<span style=\"color: green;\">%s</span>" % $1}
  text.gsub!(/%black%([^%]+)/) {"<span style=\"color: black;\">%s</span>" % $1}

  # preprocess link
  text.gsub!(/\(Attach\:\)/, "Attach:")
  # anchor [[#anchor]]  
  text.gsub!(/\[\[\s*#([^\|\s]+)\s*\]\]/) {"<a id=\"%s\"></a>" % $1}

  # links [[link | text]]
  text.gsub!(/\[\[([^\]]*?)\s*\|\s*([^\]]*?)\]\]/) do 
    link = $1
    linktext = $2
    convert_link(link, linktext, filename, pages)
  end
  # hidden link [[(link)text]]
  text.gsub!(/\[\[\((.*?)\s*\)\s*(.*?)\]\]/) do 
    link = $1 + $2
    linktext = $2
    convert_link(link, linktext, filename, pages)
  end
  # [[text->link]]
  text.gsub!(/\[\[(.*?)\s*->\s*(.*?)\]\]/) do 
    link = $2
    linktext = $1
    convert_link(link, linktext, filename, pages)
  end
  # [[link]]
  text.gsub!(/\[\[([^\|]*?)\]\]/) do
    link = $1
    convert_link(link, nil, filename, pages)
  end

  # %newwin% will set the link so that browser will open up a new windows
  # when user clicks. Remove it as it markdown has no specification.
  text.gsub!("%newwin%", "")
  text.gsub!("%newin%", "")

  # some email address is not included in the link
  text.gsub!("mailto:", "")

  # comments
  # (:if false) ... (:ifend:)
  text.gsub!(/\(:if false:\)(.*)\(:ifend:\)/m) {"<!--- %s --->" % $1.strip}
  # (:if false) ....
  text.gsub!(/\(:if false:\)(.*)/m) {"<!--- %s --->" % $1.strip}
  # (:comment ... :)
  text.gsub!(/\(:comment(.*):\)/) {"<!--- %s --->" % $1.strip}
  # {# ... #}
  text.gsub!(/\{\#(.*)\#\}/m) {"<!--- %s --->" % $1.strip}

  # break into lines for tables and other post prcocessing
  lines = text.split("\n")
  row = 0
  while row < lines.length
    # table ||
    if lines[row].start_with?(/\|\|[^|].*/)
      lines, row = convert_table(lines, row)
    end
    # directives eg. (:notitlegroup:)
    if /\(\:(.*?)\:\)/.match?(lines[row])
      lines, row = convert_directives(lines, row)
    end
    row += 1
  end

  row = 0
  while row < lines.length
    if lines[row] == "\\"
      # Unlike standard md, wiki.js renders a breakline when there is only
      # 1 breakline, so one linebreak is enough.
      # convert breaklinbe "\" into blank line
      lines[row] = ""
      if lines[row + 1].start_with?(/\#{1,}/)
        puts ">>>"
        lines.insert(row, "")
      end
    elsif lines[row].end_with?("\\")
      # delete trailing "\"
      lines[row] = lines[row][0..-2]
    end

    row += 1
  end

  # swap back code blocks
  rows_code = []
  for i in 0..lines.length-1
    if lines[i] == "XXXCODEBLOCKXXX"
      lines[i] = codes.shift()
      rows_code.push(i)
    end
  end

  def find_consecutive(xs)
    if xs.empty?
      return []
    end
    result = []

    start = 0
    for i in 1..xs.length-1
      if xs[i] != xs[i-1] + 1
        result.push([start, i-1])
        start = i
      end
    end

    result.push([start, xs.length-1])
    return result
  end

  # insert ``` to format code block
  insert_count = 0
  for rs in find_consecutive(rows_code)
    start = rows_code[rs[0]]
    fin = rows_code[rs[1]]
    lines.insert(start+insert_count, "```")
    insert_count += 1
    lines.insert(fin+1+insert_count, "```")
    insert_count += 1
  end

  text = lines.join("\n")
  return text
end

# def isimage?(file)
#   puts file
#   return file.downcase.end_with?("png", "jpg", "jpeg", "tif", "tiff")
# end

def convert_directives(lines, row)
  directive = /\(\:(.*?)\:\)/.match(lines[row])[1]
  cur_row = row
  if directive.start_with?("table")
    lines, row = table_directive(lines, row)
  # elsif directive.start_with?("if false")
  #   lines, row = comment_directive(lines, row)
  else
    lines.delete_at(cur_row)
    row -=1
  end
  # TODO all other directives are ignored
  # some common ones worth to include: title, cellnr,
  return lines, row
end

def table_directive(lines, row)
  puts "converting table directives"
  ncols = 0
  headers = []
  cells = []
  start_row = row   # => (:table ...)
  attr_line = /\(\:(.*?)\:\)/.match(lines[row])[1].split(" ")[1..-1]
  attr = {}
  for a in attr_line
    k, v = a.split("=")
    attr[k] =v
  end
  align_conv = {"left" => ":---", "center" => ":---:", "right" => "---:"}

  row += 1
  while lines[row] != "(:tableend:)"
    puts lines[row]
    el = /\(\:(.*?)\:\)/.match(lines[row])
    if el.nil?
      el = "unknown"
    else
      el = el[1].split(" ")[0]
    end
    if el == "head"
      ncols += 1
      headers.append(lines[row].split(":)")[1..-1].join())
    elsif el == "cell"
      ncols = ncols == 0 ? 3 : ncols
      if cells.length % ncols == ncols -1
        cells.append("%s |\n" % lines[row].split(":)")[1..-1].join())
      else
        cells.append("%s " % lines[row].split(":)")[1..-1].join())
      end
    elsif el == "headnr"
      ncols = ncols == 0 ? 3 : ncols
      if cells.length % ncols == ncols-1
        cells.append("**%s** |\n" % lines[row].split(":)")[1..-1].join())
      else
        cells.append("**%s** " % lines[row].split(":)")[1..-1].join())
      end
    elsif el == "comment"
      # TODO comment is ignored
    else
      # merge into last cell
      if cells.empty?
        cells.append("%s" % lines[row])
      elsif cells[-1].end_with?("\n")
        cells[-1] = "%s %s\n" % [cells[-1][0..-3], lines[row]]
      else
        cells[-1] = "%s %s" % [cells[-1], lines[row]]
      end
    end
    row += 1
  end

  end_row = row
  for i in start_row..end_row
    lines.delete_at(start_row)
  end

  header_line = "| %s |" % headers.join(" | ")
  format_line = ("| %s " % align_conv[attr["align"]]) * ncols  + "|"
  cell_line = "| %s" % cells.join("| ")

  lines.insert(start_row, header_line)
  lines.insert(start_row+1, format_line)
  lines.insert(start_row+2, cell_line)
  row = start_row + 2
  return lines, row
end

def comment_directive(lines, row)
  # turn hidden comment into visible strike-through
  # TODO is there similar features in md?
  lines.delete_at(row)
  while lines[row] != "(:ifend:)"
    t = lines[row].empty? ? "" : "~~%s~~" % lines[row]
    lines[row] = t
    row += 1
  end
  lines.delete_at(row)
  row -=1
  return lines, row
end

def convert_table(lines, row)
  puts "converting table"
  puts row
  attr_line = lines[row].split(" ")[1..-1]
  attr = {}
  for a in attr_line
    k, v = a.split("=")
    attr[k] =v
  end
  if !attr.has_key?("align")
    attr["align"] = "center"
  end
  lines.delete_at(row)
  
  header = lines[row] 
  ncols = header.scan("||").length - 1
  # consider only align attribute for now
  align_conv = {"left" => ":---", "center" => ":---:", "right" => "---:"}
  attr_md = ("| %s "  % align_conv[attr["align"]]) * ncols + "|"
  lines[row].gsub!(/\|\|/, "|")
  lines.insert(row+1, attr_md)

  row += 2
  while (!lines[row].nil? && !lines[row].empty? && lines[row].include?("||"))
    lines[row].gsub!(/\|\|/, "|")
    row += 1
  end
  return lines, row
end


def convert_link(link, linktext, filename, pages)
  # pmwiki will trim all white space for link
  # TODO double check on attachments
  link = link.nil? ? nil : link.strip
  linktext = linktext.nil? ? nil : linktext.strip
  full_link = []
  if link.start_with? "Attach:"
    full_link = ["/uploads"]
    # link to files in uploads
    # the link can point to files under another note eg. Attach:Main.links/logo.png
    # or it can be current note (default) eg. logo.png 
    if link.split("/").length > 1
      note = link.split("/")[0].split(":")[1]
      file = link.split("/")[1..-1]
      note.gsub!(".", "/")
      full_link.concat([note, file])
    else 
      full_link = full_link.concat(filename.split("."))
      file = link.split(":")[1..-1].join
      full_link.push(file)
    end
  elsif link.start_with? "mailto:"
    link = link.gsub!("mailto:", "")
    full_link = [link]
  elsif link.match? /http|www/
    # link to external site
    full_link = [link]
  elsif link.start_with?("#")
    # link to anchors
    # anchors will be converted before
    full_link = [link]
  else
    # link to internal page
    if link.include? "."
      book = link.split(".")[0]
      page = link.split(".")[1..-1].join + ".md"
    elsif link.include? "/"
      book = link.split("/")[0]
      page = link.split("/")[1..-1].join + ".md"
    else
      book, page = which_book(pages, link)
      page = page + ".md"
      if link.empty? or book.empty?
        puts ">>> empty link in %s" % [filename]
      end
    end
    full_link = ["/"+book, page]
  end
  # no linktext or omitted linktext
  if linktext === nil or linktext == "+"
    linktext = full_link[-1]
    if linktext.end_with? ".md"
      linktext = linktext.split(".")[0..-2].join
    end
  end
  # check if it is an image
  full_link = full_link.join("/")
  suffix = full_link.split(".")[-1]
  isimage = suffix.downcase.end_with?("png", "jpg", "jpeg", "tif", "tiff")
  # url cannot have space
  full_link.gsub!(/\s/, "%20")
  if isimage
    return "![%s](%s)" % [linktext, full_link]
  else
    return "[%s](%s)" % [linktext, full_link]
  end
end

# user defined
pm_dir = "./pmwiki"
md_dir = "./markdown"
link_excludes = Set[""]
parse_excludes = Set[""]


# preprocess
pages = Hash.new
for filename in Dir.entries(pm_dir).select { |f| File.file? File.join(pm_dir, f) }
  if link_excludes.include? filename
    next
  end
  book = filename.split(".")[0]
  if !(pages.keys.include? book)
    pages[book] = Set[]
  end
  page = filename.split(".")[1..-1].join
  pages[book].add(page)
end

def which_book(pages, page)
  # pmwiki will strip space and "_", and ignore case when finding the linked page
  page_mod = page.downcase
  page_mod = page_mod.gsub("_", "")
  page_mod = page_mod.gsub("(", "")
  page_mod = page_mod.gsub(")", "")
  page_mod = page_mod.gsub(/\s/, "")

  for (k, v) in pages
    for p in v
      if p.downcase == page_mod
        return k, p
      end
    end
  end
  return "", ""
end

# parsing

for filename in Dir.entries(pm_dir).select { |f| File.file? File.join(pm_dir, f)}
  if parse_excludes.include? filename
    next
  end
  puts filename
  book = filename.split(".")[0]
  book_dir = File.join(md_dir, book)
  page = filename.split(".")[1..-1].join
  md_text = pm2md(pm_dir, filename, pages)
  if !File.directory? book_dir
    Dir.mkdir(book_dir)
  end
  File.write(File.join(book_dir, page + ".md"), md_text)
end

