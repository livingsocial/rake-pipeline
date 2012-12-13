# Rake::Pipeline Basics

`Rake::Pipeline` provides a basic extraction over a build process. It
doesn't have many filters out of the box, but it is very powerful. This
guide gives you an introduction to `Rake::Pipeline`. `Rake::Pipeline`
was originally designed for frontend development (HTML, CSS,
Javascript). The examples assume this type of project just to create
some context.

## Getting Started

`Rake::Pipeline` comes with two main functionalities out of the box:
matching and concatentation. You can specify a match (IE: all css files)
then run them through a concatenation filter (combine them into one
file). There is also an order concatenation filter which allows you to
specify order (A should come before B).

Your pipeline is written in an `Assetfile`. The `Assetfile` uses a nice
DSL to make things easier. The `Assetfile` should live in your project's
root directory. 

Let's get started by writing a basic pipeline. Assume we have this
directory structure:

```
/source
  /css
  /javascript
/compiled 
Assetfile
```

The pipeline should simply concatenate all the individual JSS and CSS
files into single files. So the JSS and CSS directories are the inputs
and 2 files are outputs. The `source` directory is input and the output
will go into `compiled`. Here's the `Assetfile` to do just that:

```ruby
# input defines operations on a set of files. All files processed in
# this block go into the output directory
input "source" do

  # Select all the CSS files
  match "css/**/*.css" do

    # concatenate all files in directory into a file named
    # "application.css"
    concat "application.css"
  end

  # Repeat for javascript files
  match "javascript/**/*.js" do
    concat "application.js"
  end
end

# Set the Pipeline's output directory
output "compiled"
```

Now run `rakep build` from the project root to compile everything.
Given there are files in `source/css` and `source/javascript` you will
see files in `compiled` named `application.js` and `application.css`.
You've just written your first pipeline!

## Previewing Your Work

`Rake::Pipeline` also comes with a bundled preview server. Let's add an
HTML file to the source directory to serve the compiled site. Here's the
HTML:

```html
<!-- source/index.html -->

<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Rake::Pipeline Example</title>
  <link rel="stylesheet" href="/application.css">
</head>
<body>
  <script src="/application.js"></script>
</body>
</html>
```

Save that file in `source/index.html`. Now we must add some more code to
the `Assetfile` to copy the HTML file into the output directory.
`Rake::Pipeline` also bundles a copy filter. Note that this isn't
actually a separate filter, but a file that concatenates itself to a
different location. In short, `concat` is aliased to `copy` as well.
Here's the updated `Assetfile`:

```ruby
# input defines operations on a set of files. All files processed in
# this block go into the output directory
input "source" do

  # Select all the CSS files
  match "css/**/*.css" do

    # concatenate all files in directory into a file named
    # "application.css"
    concat "application.css"
  end

  # Repeat for javascript files
  match "javascript/**/*.js" do
    concat "application.js"
  end

  # Explicitly select the HTML file. We don't want to copy
  # over anything else
  match "index.html" do

    # copy also accepts a block. When called without any arguments it
    # simply uses the same filename
    copy
  end
end

# Set the Pipeline's output directory
output "compiled"
```

Now we can run `rakep server` inside the projects root. You'll see some
output in the terminal with a URL to connect to. Now you an preview your
work as you go.

## Writing Filters

It's very likely that you'll need to do more than just copy and
concatenate files. You must write your own filters to do this. Luckily,
writing filters is pretty easy. Filters are classes that have
`generate_output` method. This is core API requirement. There also other
method you may implement, but this is the most important. Let's take a
stab at writing a coffeescript filter. 

Filters are Ruby classes. They map a set of inputs to outputs and
finally generate the output. Here is an absolute bare bones filter:

```ruby
# Inherit from Rake::Pipeline::Filter to get basic API implemented
class CoffeeScriptFilter < Rake::Pipeline::Filter

  # This method takes the input files and does whatever is required
  # to generate the proper output.
  def generate_output(inputs, output)
    inputs.each do |input|
      output.write input.read
    end
  end
end
```

Notice `generate_output`'s method signature: `inputs` and `output`. The
default semantic is to take N input files and map them to one output
file. You can overide this or do much more fancy things. This is covered
in a different file. We could use this filter like this:

```ruby
input "source" do
  match "**/*.coffee" do
    filter CoffeeScript
  end
end

output "compiled"
```

Now this filter doesn't do anything at the moment besides copy the
files. Time to implement coffeescript compiling.

```ruby
require "coffee-script"

class CoffeeScriptFilter < Rake::Pipeline::Filter
  def generate_output(inputs, output)
    inputs.each do |input|
      output.write CoffeeScript.compile(input.read)
    end
  end
end
```

Great! Now the CoffeeScript files are compiled to JavaScript. However,
you may have noticed they are compiled "in place". This means
`source/app.coffee` will become `source/app.coffee` but as JavaScript.
This works in our simple example, but what happens when we need to work
with Javascript later in the pipeline or next build steps expect ".js"
files? The filter has to customize the name. The most correct thing to
do is make the output file has the same name except as ".js". 

This behavior is defined in the filter's initializer. This may seem odd
to you. It was odd to me until I understood what was happening.
`Rake::Pipeline` instantiates all the filters in order to setup how
input files map to output files before the pipeline is compiled. This is
how one filter can use another's outputs for inputs. This order must be
known at compile time, so that's why it happens here. The internal API
expects a block that takes a path and maps it to an output path.

```ruby
require "coffee-script"

class CoffeeScriptFilter < Rake::Pipeline::Filter
  def initialize(&block)
    &block ||= proc { |input| input.path.gsub(/\.coffee/, ".js")
    super(&block)
  end

  def generate_output(inputs, output)
    inputs.each do |input|
      output.write CoffeeScript.compile(input.read)
    end
  end
end
```

Let's take a fresh look at the `Assetfile` now.

```ruby
input "source" do
  match "javascript/**/*.coffee" do
    # Compile all .coffee files into.js
    filter CoffeeScript
  end

  # Select the JS generated by previous filters. 
  match "javascript/**/*.js" do
    concat "application.js"
  end

  match "css/**/*.css" do
    concat "application.css"
  end

  match "index.html" do
    copy
  end
end

output "compiled"
```

Calling the filter without a block uses the default block in the filter.
The default block that replaces ".js" with ".coffee". This is defined
with `||=` in the initializer. Conversely you could call `filter` with a
block and do what you want. Here's an example:

```ruby
# output all coffeescript files as "app.coffee.awesome"
filter CoffeeScript do |input|
  "#{input.path}.awesome"
end
```

That covers the basics of writing filters. There is much more you can do
with filters that are outside the scope of this guide. You can find many
useful (as well as plenty of examples) in the
[rake-pipeline-web-filters](https://github.com/wycats/rake-pipeline-web-filters) 
project.

That also concludes this guide. You should know everything you need to
know to get started writing your own pipelines now. There is still much
to cover though. You can find additonal information in the `examples`
directory. If you'd like to add anything to this guide or find an error
please open a pull request to fix it.
