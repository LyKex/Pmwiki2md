import os
import re
from typing import List, Dict, Set, Tuple
import argparse

# Constants
SUPPORTED_COLORS = ['red', 'blue', 'green', 'black']
IMAGE_EXTENSIONS = {'png', 'jpg', 'jpeg', 'tif', 'tiff'}
CODE_BLOCK_MARKER = "XXXCODEBLOCKXXX"

def pm2md(pm_dir: str, filename: str, pages: Dict[str, Set[str]]) -> str:
    """Convert PmWiki formatted text to Markdown.
    
    Args:
        pm_dir: Directory containing PmWiki files
        filename: Name of file to convert
        pages: Dictionary mapping book names to sets of page names
    
    Returns:
        Converted markdown text
    """
    with open(os.path.join(pm_dir, filename), 'r', encoding='utf-8') as f:
        text = f.read()

    lines = text.split('\n')
    codes = extract_code_blocks(lines)
    text = '\n'.join(lines)
    
    text = apply_text_formatting(text)
    text = process_links_and_formatting(text, filename, pages)
    
    # Process tables and directives
    lines = text.split('\n')
    lines = process_blocks(lines)
    lines = restore_code_blocks(lines, codes)
    
    return '\n'.join(lines)

def extract_code_blocks(lines: List[str]) -> List[str]:
    """Extract code blocks from text and replace with markers."""
    codes = []
    is_code = False
    for i in range(len(lines)):
        if lines[i].startswith(' ') or (is_code and not lines[i]):
            is_code = True
            codes.append(lines[i])
            lines[i] = CODE_BLOCK_MARKER
        else:
            is_code = False
    return codes

def apply_text_formatting(text: str) -> str:
    """Apply basic text formatting conversions."""
    tab = "  "
    
    # Bullet points
    text = re.sub(r'^(\s*)(\*+) ?(.*)', 
                  lambda m: " " * len(m.group(1)) + tab * (len(m.group(2)) - 1) + "- " + m.group(3), 
                  text, 
                  flags=re.MULTILINE)
    
    # Ordered list
    text = re.sub(r'^(\s*)(#+) ?(.*)', 
                  lambda m: tab * (len(m.group(2))-1) + "1. " + m.group(3), 
                  text, 
                  flags=re.MULTILINE)

    # Blockquotes
    text = re.sub(r'^->\s*(.*)', r'> \1', text, flags=re.MULTILINE)

    # Headings
    text = re.sub(r'^(!{1,6})\s*(.*)', lambda m: "#" * len(m.group(1)) + " " + m.group(2).strip(), text, flags=re.MULTILINE)

    # Text formatting
    text = re.sub(r"(?<!')'{2}([^']+)'{2}(?!')", r"*\1*", text)  # italics
    text = re.sub(r"(?<!')'{3}([^']+)'{3}(?!')", r"**\1**", text)  # bold
    text = re.sub(r"(?<!')'{4}([^']+)'{4}(?!')", r"***\1***", text)  # bold italics

    # Monospace
    text = re.sub(r'(?<!\[)\[\@{1}([^\]\@]+)\@{1}\](?!\])', r'`\1`', text)
    text = re.sub(r'(?<!\[)\@{2}([^\]\@]+)\@{2}(?!\])', r'`\1`', text)

    # Large and larger text
    text = re.sub(r'\[(?<!\+)\+{1}([^\+]+)\+{1}(?!\+)\]', r'## \1', text)
    text = re.sub(r'\[(?<!\+)\+{2}([^\+]+)\+{2}(?!\+)\]', r'# \1', text)

    # Small and smaller text (removed as no MD equivalent)
    text = re.sub(r'\[-([^\]]*)-\]', r'\1', text)
    text = re.sub(r'\[--([^\]]*)--\]', r'\1', text)

    # Strike through and underscore
    text = re.sub(r'\{-([^\}]*)-\}', r'~~\1~~', text)
    text = re.sub(r'\{\+([^\}]*)\+\}', r'_\1_', text)

    # Sub/superscript
    text = re.sub(r'\'\_([^\']*)\_\'', r'<sub>\1</sub>', text)
    text = re.sub(r'\'\^([^\']*)\^\'', r'<sup>\1</sup>', text)

    # Line breaks
    text = re.sub(r'(?<!\\)\\{1}$', '', text, flags=re.MULTILINE)
    text = re.sub(r'(?<!\\)\\{2}$', r'\\', text, flags=re.MULTILINE)
    text = re.sub(r'(?<!\\)\\{3}$', r'\n\n', text, flags=re.MULTILINE)

    return text

def process_links_and_formatting(text: str, filename: str, pages: Dict[str, Set[str]]) -> str:
    """Process links and additional formatting."""
    # Colors
    for color in SUPPORTED_COLORS:
        text = re.sub(f'%{color}%([^%]+)', 
                     rf'<span style="color: {color};">\1</span>', 
                     text)
    text = re.sub(r'%theosred%([^%]+)', 
                  r'<span style="color: #d21f15;">\1</span>', 
                  text)

    # Links preprocessing
    text = re.sub(r'\(Attach\:\)', 'Attach:', text)
    
    # Anchors
    text = re.sub(r'\[\[\s*#([^\|\s]+)\s*\]\]', r'<a id="\1"></a>', text)

    # Various link formats
    text = re.sub(r'\[\[([^\]]*?)\s*\|\s*([^\]]*?)\]\]', 
                  lambda m: convert_link(m.group(1), m.group(2), filename, pages), 
                  text)
    text = re.sub(r'\[\[\((.*?)\s*\)\s*(.*?)\]\]',
                  lambda m: convert_link(m.group(1) + m.group(2), m.group(2), filename, pages),
                  text)
    text = re.sub(r'\[\[(.*?)\s*->\s*(.*?)\]\]',
                  lambda m: convert_link(m.group(2), m.group(1), filename, pages),
                  text)
    text = re.sub(r'\[\[([^\|]*?)\]\]',
                  lambda m: convert_link(m.group(1), None, filename, pages),
                  text)

    # Remove window directives
    text = text.replace('%newwin%', '').replace('%newin%', '')
    text = text.replace('mailto:', '')

    # Comments
    text = re.sub(r'\(:if false:\)(.*)\(:ifend:\)', r'<!--- \1 --->', text, flags=re.DOTALL)
    text = re.sub(r'\(:if false:\)(.*)', r'<!--- \1 --->', text, flags=re.DOTALL)
    text = re.sub(r'\(:comment(.*):\)', r'<!--- \1 --->', text)
    text = re.sub(r'\{\#(.*)\#\}', r'<!--- \1 --->', text, flags=re.DOTALL)

    return text

def process_blocks(lines: List[str]) -> List[str]:
    row = 0
    while row < len(lines):
        if re.match(r'\|\|[^|].*', lines[row]):
            lines, row = convert_table(lines, row)
        elif re.match(r'\(\:(.*?)\:\)', lines[row]):
            lines, row = convert_directives(lines, row)
        row += 1
    return lines

def restore_code_blocks(lines: List[str], codes: List[str]) -> List[str]:
    rows_code = []
    for i in range(len(lines)):
        if lines[i] == CODE_BLOCK_MARKER:
            lines[i] = codes.pop(0)
            rows_code.append(i)

    # Add code block markers
    insert_count = 0
    for start, end in find_consecutive(rows_code):
        start_idx = rows_code[start]
        end_idx = rows_code[end]
        lines.insert(start_idx + insert_count, "```")
        insert_count += 1
        lines.insert(end_idx + 1 + insert_count, "```")
        insert_count += 1

    return lines

def find_consecutive(xs: List[int]) -> List[Tuple[int, int]]:
    if not xs:
        return []
    result = []
    start = 0
    for i in range(1, len(xs)):
        if xs[i] != xs[i-1] + 1:
            result.append((start, i-1))
            start = i
    result.append((start, len(xs)-1))
    return result

def convert_link(link: str, linktext: str, filename: str, pages: Dict[str, Set[str]]) -> str:
    """Convert PmWiki link format to Markdown link format.
    
    Args:
        link: The target of the link
        linktext: The display text for the link
        filename: Current file being processed
        pages: Dictionary of available pages
    
    Returns:
        Markdown formatted link
    """
    link = link.strip() if link else None
    linktext = linktext.strip() if linktext else None
    
    full_link = []
    if link.startswith('Attach:'):
        full_link = ['/uploads']
        if '/' in link:
            note = link.split('/')[0].split(':')[1]
            file_parts = link.split('/')[1:]
            note = note.replace('.', '/')
            full_link.extend([note] + file_parts)
        else:
            full_link.extend(filename.split('.'))
            file = ':'.join(link.split(':')[1:])
            full_link.append(file)
    elif link.startswith('mailto:'):
        link = link.replace('mailto:', '')
        full_link = [link]
    elif re.search(r'http|www', link):
        full_link = [link]
    elif link.startswith('#'):
        full_link = [link]
    else:
        if '.' in link:
            book = link.split('.')[0]
            page = '.'.join(link.split('.')[1:]) + '.md'
        elif '/' in link:
            book = link.split('/')[0]
            page = '/'.join(link.split('/')[1:]) + '.md'
        else:
            book, page = which_book(pages, link)
            page = page + '.md'
            if not link or not book:
                print(f">>> empty link in {filename}")
        full_link = ['/' + book, page]

    if linktext is None or linktext == '+':
        linktext = full_link[-1]
        if linktext.endswith('.md'):
            linktext = '.'.join(linktext.split('.')[:-1])

    full_link = '/'.join(full_link)
    suffix = full_link.split('.')[-1].lower()
    is_image = suffix in IMAGE_EXTENSIONS
    
    full_link = full_link.replace(' ', '%20')
    
    return f'![{linktext}]({full_link})' if is_image else f'[{linktext}]({full_link})'

def which_book(pages: Dict[str, Set[str]], page: str) -> Tuple[str, str]:
    page_mod = page.lower()
    page_mod = re.sub(r'[_()]', '', page_mod)
    page_mod = re.sub(r'\s', '', page_mod)
    
    for book, pages_set in pages.items():
        for p in pages_set:
            if p.lower() == page_mod:
                return book, p
    return '', ''

def convert_directives(lines: List[str], row: int) -> Tuple[List[str], int]:
    directive = re.match(r'\(\:(.*?)\:\)', lines[row]).group(1)
    cur_row = row
    if directive.startswith('table'):
        lines, row = convert_table(lines, row)
    else:
        lines.pop(cur_row)
        row -= 1
    return lines, row

def convert_table(lines: List[str], row: int) -> Tuple[List[str], int]:
    attr_line = lines[row].split(' ')[1:]
    attr = dict(a.split('=') for a in attr_line if '=' in a)
    attr.setdefault('align', 'center')
    lines.pop(row)
    
    header = lines[row]
    ncols = header.count('||') - 1
    align_conv = {'left': ':---', 'center': ':---:', 'right': '---:'}
    attr_md = '| ' + ' | '.join([align_conv[attr['align']]] * ncols) + ' |'
    lines[row] = lines[row].replace('||', '|')
    lines.insert(row + 1, attr_md)
    
    row += 2
    while row < len(lines) and lines[row] and '||' in lines[row]:
        lines[row] = lines[row].replace('||', '|')
        row += 1
    
    return lines, row

def parse_args():
    parser = argparse.ArgumentParser(
        description='Convert PmWiki files to Markdown format',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    parser.add_argument(
        'pmwiki_dir',
        help='Directory containing PmWiki files to convert'
    )
    
    parser.add_argument(
        '-o', '--output',
        default='markdown_output',
        help='Output directory for converted markdown files'
    )
    
    parser.add_argument(
        '-e', '--excludes',
        nargs='*',
        default=['Group.RecentChanges', 'Group.EditThesesArchives', 'Main.HomePage'],
        help='List of filenames to exclude from conversion'
    )
    
    return parser.parse_args()

def main():
    args = parse_args()
    
    # Validate input directory exists
    if not os.path.isdir(args.pmwiki_dir):
        raise ValueError(f"Input directory does not exist: {args.pmwiki_dir}")
    
    # Convert excludes list to set for faster lookup
    parse_excludes = set(args.excludes)
    
    # Create output directory if it doesn't exist
    os.makedirs(args.output, exist_ok=True)

    # Preprocess
    pages = {}
    for filename in os.listdir(args.pmwiki_dir):
        if not os.path.isfile(os.path.join(args.pmwiki_dir, filename)) or filename in parse_excludes:
            continue
        book = filename.split('.')[0]
        if book not in pages:
            pages[book] = set()
        page = '.'.join(filename.split('.')[1:])
        pages[book].add(page)

    # Parsing
    for filename in os.listdir(args.pmwiki_dir):
        if not os.path.isfile(os.path.join(args.pmwiki_dir, filename)) or filename in parse_excludes:
            continue
        print(filename)
        book = filename.split('.')[0]
        book_dir = os.path.join(args.output, book)
        page = '.'.join(filename.split('.')[1:])
        md_text = pm2md(args.pmwiki_dir, filename, pages)
        
        os.makedirs(book_dir, exist_ok=True)
        with open(os.path.join(book_dir, page + '.md'), 'w', encoding='utf-8') as f:
            f.write(md_text)

if __name__ == '__main__':
    main() 