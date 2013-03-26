# (c) 2013 Oliver Braun

COPYRIGHT_DATE:=	`date "+%Y"` Oliver Braun
COPYRIGHT_AUTHOR:=	
COPYRIGHT:=	$(COPYRIGHT_DATE) $(COPYRIGHT_AUTHOR)

SLIDYDIR:=	slidy

DATE=	`date "+%d.%m.%y %H:%M"`
COMMIT=	`git --no-pager log -1 --format="%h"`
GERMAN?=	--variable german="german"

# Make images using dot

IMG_DIR=	img
IMG_SRC=	

IMGS=		$(patsubst %.dot,$(IMG_DIR)/%.png,$(IMG_SRC))

$(IMG_DIR)/%.png: $(IMG_DIR)/%.dot
	dot -Tpng $< -o $@

imgs: $(IMGS)

clean-imgs:
	rm -f $(IMGS)

# HTMLs

HTMLDIR:=	html
HTMLS:=		$(patsubst %.txt,$(HTMLDIR)/%.html,$(SRCS))

$(HTMLDIR):
	mkdir -p $(HTMLDIR)

$(HTMLDIR)/%.html: %.txt
	pandoc --toc -s -S --webtex --self-contained -o $@ $<

htmls:	$(HTMLDIR) $(HTMLS)
h: htmls

# PDFs

PDFDIR:=	pdf
PDFS:=		$(patsubst %.txt,$(PDFDIR)/%.pdf,$(SRCS))

$(PDFDIR):
	mkdir -p $(PDFDIR)

$(PDFDIR)/%.pdf: %.txt
	pandoc -S --template=includes/template.tex \
	    --variable lecturename="$(LECTURE_NAME)" \
	    --variable stand="$(DATE)" \
	    --variable commit="$(COMMIT)" \
	    --variable semester="$(SEMESTER)" \
	    --variable copyright="$(COPYRIGHT)" \
	    $(GERMAN) \
	    --latex-engine=xelatex --toc -o $@ $<

pdfs:	$(PDFDIR) $(PDFS)
p: pdfs

# Presentations

PRESDIR:=	presentation
PRESS:=		$(patsubst %.txt,$(PRESDIR)/%.html,$(SRCS))

$(PRESDIR):
	mkdir -p $(PRESDIR)

$(PRESDIR)/%.html: %.txt
	sed -e "s,@commit@,$(COMMIT), ;\
	    s/@date@/$(DATE)/ ;\
		s/@copyright@/$(COPYRIGHT)/" includes/preshdr.html.in > includes/preshdr.html
	pandoc -t slidy -s -S -V slidy-url=$(SLIDYDIR) --mathml \
	   --slide-level=2 --self-contained -H includes/preshdr.html -o $@ $<
	rm includes/preshdr.html

presentations:	$(PRESDIR) $(PRESS)
# s for slidy
s: presentations

# README

README.html: README.md
	pandoc -s -S -o $@ $<

# automagically refresh browser
# taken from http://brettterpstra.com/watch-for-file-changes-and-refresh-your-browser-automatically/

watch:
	watch.rb presentation $(LECTURE_NAME)

# push to ob.cs.hm.edu

WEBIMG_DIR:=	webimg

$(WEBIMG_DIR):
	mkdir -p $(WEBIMG_DIR)

$(WEBIMG_DIR)/%.png: %.txt
	head -2 $< | \
	   gsed -e 's/^..// ; s/---[ ]*//g ; $$a\Stand: @stand@' | \
	   gsed -e '$$a\Commit: @commit@' | \
	   gsed -e "s/@stand@/$(DATE)/ ; s/@commit@/$(COMMIT)/" | \
	   convert -font Courier-Bold -pointsize 18 label:@- $@

WEBIMGS:=	$(patsubst %.txt,$(WEBIMG_DIR)/%.png,$(SRCS))

webimgs:	$(WEBIMG_DIR) $(WEBIMGS)

test:
	echo "Hallo" | gsed -e '$$a\hallo'

# last slide of the lecture
# example usage:
# make LAST="04_Klassen.html#(2)" GROUP=B lastslide
LAST:=	00.html
GROUP:=	
LASTSLIDE:=	../$(PRESDIR)/$(LAST)
LASTSLIDE_HTML:=	lastslide$(GROUP).html

lastslide: html
	sed "s,%%url%%,$(LASTSLIDE)," includes/lastslide.html > html/$(LASTSLIDE_HTML)
	rsync html/$(LASTSLIDE_HTML) ${UPLOAD_HOST}:${UPLOAD_DIR}/$(HTMLDIR)/$(LASTSLIDE_HTML)

UPLOAD_HOST=	ob.cs.hm.edu
UPLOAD_DIR=	www/static/docs/lectures/$(LECTURE_NAME)

push: all
	rsync -avz $(PDFDIR) $(HTMLDIR) $(PRESDIR) $(WEBIMG_DIR) \
	    ${UPLOAD_HOST}:${UPLOAD_DIR}

# common targets

all: imgs webimgs htmls pdfs presentations

clean:
	rm -rf $(HTMLDIR) $(PDFDIR) $(PRESDIR) $(WEBIMG_DIR)
	rm -f README.html includes/preshdr.html
