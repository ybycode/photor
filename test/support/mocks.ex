defmodule Photor.Mocks do
  # Define mocks for external dependencies
  Mox.defmock(Photor.Metadata.MockExiftool, for: Photor.Metadata.ExiftoolBehaviour)
  Mox.defmock(Photor.Photos.ThumbnailMock, for: Photor.Photos.Thumbnails)
end
