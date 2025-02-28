require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMDirectoryTest < Minitest::Test
  DIR_PATH = './.directory_test.rcmtmp'.freeze

  # Minitest.after_run do
  #   FileUtils.rm_r(DIR_PATH) if File.directory?(DIR_PATH)
  # end

  def test_create_directory
    configure_from_scratch do
      directory DIR_PATH do
        is present
      end
    end
    assert File.directory?(DIR_PATH)
  end

  def test_delete_directory
    configure_from_scratch do
      directory create do
        path DIR_PATH
        is present
      end
      directory delete do
        path DIR_PATH
        is absent
      end
    end
    refute File.directory?(DIR_PATH)
  end

  def test_purge_directory
    configure_from_scratch do
      touch create do
        path "#{DIR_PATH}/subdir/a_file.txt"
        manage directory
      end
      directory purge do
        path DIR_PATH
        is purged
        without backup
      end
    end
    refute File.directory?(DIR_PATH)
  end

  # TODO: Unit test
  def test_copy_directory_recursively
    expected_files = {}

    configure_from_scratch do
      2.times do |i|
        file "file_#{i + 10}_dest" do
          path "#{DIR_PATH}/dest_dir/file_#{i + 10}.txt"
          manage directory
          expected_files["file_#{i + 10}.txt"] = "file_#{i + 10}_dest"
          "file_#{i + 10}_dest"
        end
        file "file_#{i}_dest" do
          path "#{DIR_PATH}/dest_dir/file_#{i}.txt"
          manage directory
          expected_files["file_#{i}.txt"] = "file_#{i}_dest"
          "file_#{i}_dest"
        end
        file "file_#{i}_sub_dest" do
          path "#{DIR_PATH}/dest_dir/sub/file_#{i}.txt"
          expected_files["sub/file_#{i}.txt"] = "sub_file_#{i}_dest"
          manage directory
          "sub_file_#{i}_dest"
        end
      end

      4.times do |i|
        file "file_#{i}_source" do
          path "#{DIR_PATH}/source_dir/file_#{i}.txt"
          manage directory
          expected_files["file_#{i}.txt"] = "file_#{i}_source"
          "file_#{i}_source"
        end
        file "file_#{i}_sub_source" do
          path "#{DIR_PATH}/source_dir/sub/file_#{i}.txt"
          manage directory
          expected_files["sub/file_#{i}.txt"] = "sub_file_#{i}_source"
          "sub_file_#{i}_source"
        end
      end

      directory "#{DIR_PATH}/dest_dir" do
        recursively
        without backup
        "#{DIR_PATH}/source_dir"
      end
    end

    expected_files.each do |file_path, content|
      assert File.file?("#{DIR_PATH}/dest_dir/#{file_path}")
      assert_equal content, File.read("#{DIR_PATH}/dest_dir/#{file_path}")
    end

    actual_files = (Dir["#{DIR_PATH}/dest_dir/*"] + Dir["#{DIR_PATH}/dest_dir/*/*"]).select { File.file?(_1) }
    actual_files.each do |file_path|
      key = file_path.sub("#{DIR_PATH}/dest_dir/", '')
      assert expected_files.key?(key)
      assert_equal File.read(file_path), expected_files[key]
    end
  end
end
