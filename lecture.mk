# (c) 2013 Oliver Braun

UPLOAD_HOST?=	ob.cs.hm.edu
UPLOAD_DIR?=	www/static/docs/lectures/$(LECTURE_NAME)
LECTURE_URL?=	http://$(UPLOAD_HOST)/lectures/$(LECTURE_NAME)
# Sources are available on GitHub?
GITHUB?=	NO

PUSH_HTML?=				YES
PUSH_PDF?=				YES
PUSH_PRESENTATIONS?=	YES
PUSH_WEBIMGS?=			NO
PUSH_SRC?=				NO

PUSH_DROPBOX?=			NO
DROPBOX_DIR?=			/dev/null
SOLUTIONS_DIR?=			/dev/null

WATCH_DIR?=	presentation

COPYRIGHT_DATE?=	`date "+%Y"`
COPYRIGHT_AUTHOR?=	Oliver Braun
COPYRIGHT?=	$(COPYRIGHT_DATE) $(COPYRIGHT_AUTHOR)

SLIDYDIR:=	slidy

DATE=	`date "+%d.%m.%y %H:%M"`
ifeq ($(GITHUB),YES)
	COMMIT=	`git --no-pager log -1 --format="%h"`
	SHOWGITHUB=	   --variable github="yes"
else
	COMMIT= #
	SHOWGITHUB= #
endif
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

HTML_TOC?= --toc

ifdef USE_MATHML
	EMBEDDEDTEX=	--mathml
else
	EMBEDDEDTEX=	--webtex
endif

$(HTMLDIR)/%.html: %.txt
	sed -e "s,@commit@,$(COMMIT), ;\
	    s/@date@/$(DATE)/ ;\
	    s/@lecturename@/$(LECTURE_NAME)/ ;\
		s/@copyright@/$(COPYRIGHT)/" includes/footer.html.in > includes/footer.html
ifeq ($(GITHUB),NO)
	sed -e "/GitHub/d" -i "" includes/footer.html
endif
	pandoc \
	   $(HTML_TOC) \
	   --css includes/ocean.css -A includes/footer.html \
	   -s -S \
	   $(EMBEDDEDTEX) \
	   --self-contained -o $@ $<
	rm includes/footer.html

htmls:	$(HTMLDIR) $(HTMLS)
h: htmls

# PDFs

PDFDIR:=	pdf
PDFS:=		$(patsubst %.txt,$(PDFDIR)/%.pdf,$(SRCS))

$(PDFDIR):
	mkdir -p $(PDFDIR)

PDF_TOC?= --toc

$(PDFDIR)/%.pdf: %.txt
	pandoc -S --template=includes/template.tex \
	    --variable lecturename="$(LECTURE_NAME)" \
	    --variable stand="$(DATE)" \
	    --variable commit="$(COMMIT)" \
	    --variable semester="$(SEMESTER)" \
	    --variable copyright="$(COPYRIGHT)" \
	    $(GERMAN) \
	    $(SHOWGITHUB) \
	    --latex-engine=xelatex \
	    $(PDF_TOC) \
	    -o $@ $<

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
	pandoc -t slidy -s -S -V slidy-url=$(SLIDYDIR) \
	   $(EMBEDDEDTEX) \
	   --slide-level=2 --self-contained -H includes/preshdr.html -o $@ $<
	rm includes/preshdr.html

presentations:	$(PRESDIR) $(PRESS)
# s for slidy
s: presentations

# Sources

SRC_DIR?=	src

# README

README.html: README.md
	pandoc -s -S -o $@ $<

# automagically refresh browser
# taken from http://brettterpstra.com/watch-for-file-changes-and-refresh-your-browser-automatically/

watch:
	watch.rb $(WATCH_DIR) $(LECTURE_NAME)

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

push: all
ifeq ($(PUSH_HTML),YES)
	rsync -avz $(HTMLDIR) $(UPLOAD_HOST):$(UPLOAD_DIR)
endif
ifeq ($(PUSH_PDF),YES)
	rsync -avz $(PDFDIR) $(UPLOAD_HOST):$(UPLOAD_DIR)
endif
ifeq ($(PUSH_PRESENTATIONS),YES)
	rsync -avz $(PRESDIR) $(UPLOAD_HOST):$(UPLOAD_DIR)
endif
ifeq ($(PUSH_WEBIMGS),YES)
	rsync -avz $(WEBIMG_DIR) $(UPLOAD_HOST):$(UPLOAD_DIR)
endif
ifeq ($(PUSH_SRC),YES)
	rsync -Lavz $(SRC_DIR) $(UPLOAD_HOST):$(UPLOAD_DIR)
endif
ifeq ($(PUSH_DROPBOX),YES)
	rsync -av $(SOLUTIONS_DIR) $(DROPBOX_DIR)
endif

# common targets

all: imgs htmls pdfs presentations

clean:
	rm -rf $(HTMLDIR) $(PDFDIR) $(PRESDIR) $(WEBIMG_DIR)
	rm -f README.html includes/preshdr.html
