Your build process may become to complex to express in terms of a single
`input` block. You can break your `Assetfile` into multiple input
blocks. You can also use an `input`'s output as the input for a new
`input` block.

Say you have different pipelines for different types of files. There is
one for JS, CSS, and other assets. The output of these 3 different build
steps needs be the input for the next build step. You can express that
rather easily with `Rake::Pipeline`. Here are the pipelines for the
different types. The internals are left out because they are not
relavant to this example.

```ruby
# Stage 1
input "js" do
  # do JS stuff
end

input "css" do
  # do css stuff
end

input "assets" do
  # do asset stuff
end
```

Now let's add a line at the top of the `Assetfile`. Let's stay that all
the pipelines should output into one directory.

```ruby
# All `input` blocks will output to `tmp/stage1` unless output is
# set again
output "tmp/stage1"

input "js" do
  # do JS stuff
end

input "css" do
  # do css stuff
end

input "assets" do
  # do asset stuff
end
```

Now let's hookup stage 2.

```ruby
# Stage 1
output "tmp/stage1"
input "js" do
  # do JS stuff
end

input "css" do
  # do css stuff
end

input "assets" do
  # do asset stuff
end

# Stage 2
# output of next input block should go to the real output directory
output "compiled"
input "tmp/stage1" do
  # do stage 2 stuff
end
```

You can repeat this process over and over again for as many stages as
you like. Just remember that the final input should output to where you
want the final files. Also, keep the intermediate build steps inside
temp directories so they are ignored by source control.
