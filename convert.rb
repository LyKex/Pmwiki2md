
def pm2md(pm_dir, filename, pages)
  text = File.read("#{pm_dir}/#{filename}")
  tab = "  "
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
  # monospace [@..@], @@..@@, or @..@
  text.gsub!(/(?<!\[)\[\@{1}([^\]\@]+)\@{1}\](?!\])/) {"`" + $1.strip + "`"}
  text.gsub!(/(?<!\[)\@{2}([^\]\@]+)\@{2}(?!\])/) {"`" + $1.strip + "`"}
  text.gsub!(/(?<!\[)\@{1}([^\]\@]+)\@{1}(?!\])/) {"`" + $1.strip + "`"}
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
  text.gsub!(/%red%\s(\S+)/) {"<span style=\"color: red;\">%s</span>" % $1}
  text.gsub!(/%blue%\s(\S+)/) {"<span style=\"color: blue;\">%s</span>" % $1}
  text.gsub!(/%green%\s(\S+)/) {"<span style=\"color: green;\">%s</span>" % $1}
  text.gsub!(/%theosred%\s(\S+)/) {"<span style=\"color: #d21f15;\">%s</span>" % $1}

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

  # comment that will not shown
  # (:if false) ... (:ifend:)
  text.gsub!(/\(:if false:\)(.*)\(:ifend:\)/m) {"<!--- %s --->" % $1.strip}
  # (:if false) ....
  text.gsub!(/\(:if false:\)(.*)/m) {"<!--- %s --->" % $1.strip}
  # (:comment ... :)
  text.gsub!(/\(:comment(.*):\)/) {"<!--- %s --->" % $1.strip}
  # {# ... #}
  text.gsub!(/\{\#(.*)\#\}/) {"<!--- %s --->" % $1.strip}

  # break into lines for tables and other post prcocessing
  lines = text.split("\n")
  row = 0
  while row < lines.length
    if lines[row].start_with?(/\|\|[^|].*/)
      lines, row = convert_table(lines, row)
    end
    # directives eg. (:notitlegroup:)
    if /\(\:(.*?)\:\)/.match?(lines[row])
      lines, row = convert_directives(lines, row)
    end
    row += 1
  end

  # convert breaklinbe "\" into <br>
  row = 0
  while row < lines.length - 1
    if lines[row] == "\\"
      lines[row] = "<br>"
      if lines[row + 1].start_with?(/\#{1,}/)
        puts ">>>"
        lines.insert(row, "")
      end
    end
    row += 1
  end

  text = lines.join("\n")
  return text
end

def convert_directives(lines, row)
  directive = /\(\:(.*?)\:\)/.match(lines[row])[1]
  cur_row = row
  if directive.start_with?("table")
    lines, row = table_directive(lines, row)
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
  link = link.gsub(/\s+/, "") 
  linktext = linktext.nil? ? nil : linktext.strip
  full_link = []
  if link.include? "Attach"
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
    else
      book, page = which_book(pages, link)
      page = link + ".md"
      if link.empty? or book.empty?
        puts ">>> link: %s book: %s" % [link, book]
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

# configure
pm_dir = ...              # directory of pmwiki file
md_dir = ...              # directory to save converted markdowns
link_excludes = Set[...]  # files to ignore when resolving links
parse_excludes = Set[...] # files to ignore for conversion


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
  # pmwiki will strip space and "_", and ignore casewhen finding the linked page
  page_mod = page.downcase
  page_mod = page_mod.gsub("_", "")
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

