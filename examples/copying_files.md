The `copy` method also accepts an array. You can use this to copy the
file into multiple locations. Here's an example `Assetfile`:

```
input "source" do
  match "*.js" do
    copy do |input|
      ["/staging/#{input.path}", "/production/#{input.path}"]
    end
  end
end
```
