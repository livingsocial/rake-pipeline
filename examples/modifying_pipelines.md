You may want to do some trickery with your input files. Here is a use
case: you need to sort your files in a custom way. The easiest way to do
this is to insert a new pipeline into your pipeline. This pipeline must
act like a filter because it will be used as such. Let's start out by
describing the most basic pipeline:

```ruby
class PassThroughPipeline < Rake::Pipeline
  # this need to act like a filter
  attr_accessor :pipeline

  # simply return the original input_files
  def output_files
    input_files
  end

  # this is very imporant! define this method
  # to do nothing and files will not be copied 
  # to the output directory
  def finalize
  end
end
```

At this point you can insert it into your pipeline:

```ruby
input "**/*.js" do
  # stick our pass through
  pass_through = pipeline.copy PassThroughPipeline
  pipeline.add_filter pass_through
  
  # now continue on with your life
  concat "application.js"
end
```

Now we can begin to do all sorts of crazyness in this pass through
pipeline. You could expand directories to groups of files or you could
collapse then. You could even skip files if you wanted to. Hell, you can
even sort them--and that's what we're going to do. So let's get going

```ruby
class SortedPipeline < PassThroughPipeline
  def output_files
    super.sort do |f1, f2|
      # just an easy example of reverse sorting
      f2.fullpath <=> f1.fullpath
    end
  end
end
```

Now add it to the pipeline:

```ruby
input "**/*.js" do
  # stick our pass through
  pass_through = pipeline.copy SortedPipeline
  pipeline.add_filter pass_through

  # now continue on with your life
  concat "application.js"
end
```

Voila! You can sort stuff. Let your mind run wild with possibilities!
