
try do
  IO.puts "Loading model..."
  {:ok, model_info} = Bumblebee.load_model({:hf, "sentence-transformers/all-MiniLM-L6-v2"})
  IO.puts "Model loaded."
  
  {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "sentence-transformers/all-MiniLM-L6-v2"})
  IO.puts "Tokenizer loaded."
  
  IO.puts "Creating serving..."
  serving =
    Bumblebee.Text.text_embedding(
      model_info,
      tokenizer
    )
  IO.puts "Serving created."

  IO.puts "Running prediction..."
  result = Nx.Serving.run(serving, "Hello world")
  IO.inspect(result.embedding, label: "Embedding")
  IO.puts "Success!"
rescue
  e -> 
    IO.puts "\n\nCRITICAL ERROR:\n#{inspect(e)}\n"
end
