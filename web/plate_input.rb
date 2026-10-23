# frozen_string_literal: true

# The plate a request brings, from the file chosen or the text pasted, within
# the size the app accepts; and the error page a request is turned back with.
# Mixed into the app's routes.
module PlateInput
  private

  # SVG from the file upload when one was chosen, otherwise from the textarea
  def submitted_svg
    svg = uploaded_svg.to_s
    svg = params[:svg].to_s if svg.empty?
    limit = CistergraphiaApp::MAX_SVG_BYTES
    halt_with 413, "SVG is limited to #{limit / 1024} KB" if svg.bytesize > limit
    svg
  end

  # Reads one byte past the limit so oversized uploads are detected without loading them whole
  def uploaded_svg
    upload = params[:file]
    upload[:tempfile].read(CistergraphiaApp::MAX_SVG_BYTES + 1) if upload.is_a?(Hash) && upload[:tempfile]
  end

  def halt_with(status, message)
    @error_message = message
    halt status, erb(:error)
  end
end
