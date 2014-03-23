# Introduction
The plugins are extensions of already available plugins and have beend modifed to fit my custom needs.

# photos_tag.rb
The original syntax has been extended:

Original:

```
{% photo /path/to/photo.jpg %}
```

New: 

```markdown
{% photo photo1.jpg My Photo %}
{% photo /path/to/photo.jpg %}
{% photo /path/to/photo.jpg default licence:url/to/licence Title %}
{% photo /path/to/photo.jpg default licence:default id:<cssid> Title %}
{% photo /path/to/photo.jpg default license:default form:<cssclass> Title %}
```

For the photo prefix tag some variables must be declared in `_config.yml`:

```yaml
# Photos-Tag Prefix
photos_prefix           : http://images.micronarrativ.org/
photos_default_licence  : http://url.to.license.page
photos_licence_icon     : /path/to/license/image.jpg
```

The css id and class used in the parameter *id* and *form* should be defined in `/sass/custom/_styles.css`.

```css
 #mainimg {
   float:right;
   margin:5px;
   } 
```

# video_tag.rb
Plugin for including videos with a flash backup. Not my own work.

```
{% video http://site.com/video.mp4 720 480 http://site.com/poster-frame.jpg %}
```

# vimeo_tag.rb
The original plugin has been changed a bit in order to include the videos centered in the page.  
Otherwise the syntax is as usual:

```
{% vimeo <videocode> %}
```

# youtube_tag.rb
The original plugin has been switched over to use https instead of http.  
Otherwise the syntax is identical:

```
{% youtube oHg5SJYRHA0 %}
```

This will include and center videos from [Youtube](https://www.youtube.com).