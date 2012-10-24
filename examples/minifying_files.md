Minifying files is a very common task for web developers. There are two
common uses cases: 

1. Create an unminified and minified file
2. Generate a minified file from an unminifed file.

Doing #2 is very easy with rake pipeline. Doing #1 is slightly more
complicated. For these examples assume there is a `MinifyFilter` that
actually does the work.

Doing the first use case creates a problem. Filters are destructive.
That means if you change one file (move it, rewrite) it will not be
available for the next filters. For example, taking `app.js` and
minifying it will remove the unminfied source from the pipeline. 

You must first duplicate the unminified file then minify it. Here's an
`Assetfile`

```ruby
input "source" do
  match "application.js" do
    # Duplicate the source file for future filters (application.js)
    # and provide duplicate in "application.min.js" for minifcation
    copy ["application.js", "application.min.js"]
  end

  match "application.min.js" do
    filter MinifyFilter
  end
end

output "compiled"
```

Now you have two files: `application.js` and `application.min.js`. You
can use this same technique everytime you need to transform a file and
keep the source around for future filters.
