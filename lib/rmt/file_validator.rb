require 'fileutils'

module RMT::FileValidator
  private

  def validate_local_file(file_reference)
    if valid_on_disk?(file_reference)
      DownloadedFile.track_file(checksum: file_reference.checksum,
                                checksum_type: file_reference.checksum_type,
                                local_path: file_reference.local_path,
                                size: file_reference.size)
      return true
    end

    # Remove invalid files/DB entries as soon as they are found
    FileUtils.remove_file(file_reference.local_path, force: true)
    DownloadedFile.where(local_path: file_reference.local_path).destroy_all
    false
  end

  def find_valid_files_by_checksum(checksum, checksum_type)
    files = DownloadedFile
      .where(checksum: checksum, checksum_type: checksum_type).to_a

    files.delete_if do |file|
      next false if valid_on_disk?(file)

      # Remove invalid files/DB entries as soon as they are found
      FileUtils.remove_file(file.local_path, force: true)
      file.destroy
      true
    end
  end

  def valid_on_disk?(file)
    return false unless File.exist?(file.local_path)

    has_valid_metadata = (File.size(file.local_path) == file.size)
    if deep_verify
      has_valid_metadata &= RMT::ChecksumVerifier
        .match_checksum?(file.checksum_type, file.checksum, file.local_path)
    end

    has_valid_metadata
  end
end
