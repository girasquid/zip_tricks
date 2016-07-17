require_relative '../spec_helper'

describe ZipTricks::Microzip do
  class ByteReader < Struct.new(:io)
    def read_2b
      io.read(2).unpack('v').first
    end
    
    def read_2c
      io.read(2).unpack('CC').first
    end
    
    def read_4b
      io.read(4).unpack('V').first
    end
    
    def read_8b
      io.read(8).unpack('Q<').first
    end
    
    def read_n(n)
      io.read(n)
    end
  end
  
  it 'raises an exception if the filename is non-unique in the already existing set' do
    z = described_class.new(StringIO.new)
    z.add_local_file_header(filename: 'foo.txt', crc32: 0, compressed_size: 0, uncompressed_size: 0, storage_mode: 0)
    expect {
      z.add_local_file_header(filename: 'foo.txt', crc32: 0, compressed_size: 0, uncompressed_size: 0, storage_mode: 0)
    }.to raise_error(/already/)
  end

  it 'raises an exception if the filename does not fit in 0xFFFF bytes' do
    longest_filename_in_the_universe = "x" * (0xFFFF + 1)
    z = described_class.new(StringIO.new)
    expect {
      z.add_local_file_header(filename: longest_filename_in_the_universe, crc32: 0, compressed_size: 0, uncompressed_size: 0, storage_mode: 0)
    }.to raise_error(/filename/)
  end
  
  describe '#add_local_file_header' do
    it 'writes out the local file header for an entry that fits into a standard ZIP' do
      buf = StringIO.new
      zip = described_class.new(buf)
      mtime = Time.utc(2016, 7, 17, 13, 48)
      zip.add_local_file_header(filename: 'first-file.bin', crc32: 123, compressed_size: 8981,
        uncompressed_size: 90981, storage_mode: 8, mtime: mtime)
      
      buf.rewind
      br = ByteReader.new(buf)
      expect(br.read_4b).to eq(0x04034b50) # Signature
      expect(br.read_2b).to eq(20)         # Version needed to extract
      expect(br.read_2b).to eq(0)          # gp flags
      expect(br.read_2b).to eq(8)          # storage mode
      expect(br.read_2b).to eq(28160)      # DOS time
      expect(br.read_2b).to eq(18673)      # DOS date
      expect(br.read_4b).to eq(123)        # CRC32
      expect(br.read_4b).to eq(8981)       # compressed size
      expect(br.read_4b).to eq(90981)      # uncompressed size
      expect(br.read_2b).to eq('first-file.bin'.bytesize)      # byte length of the filename
      expect(br.read_2b).to be_zero        # size of extra fields
      expect(br.read_n('first-file.bin'.bytesize)).to eq('first-file.bin') # the filename
    end
    
    it 'writes out the local file header for an entry with a UTF-8 filename, setting the proper GP flag bit' do
      buf = StringIO.new
      zip = described_class.new(buf)
      mtime = Time.utc(2016, 7, 17, 13, 48)
      zip.add_local_file_header(filename: 'файл.bin', crc32: 123, compressed_size: 8981,
        uncompressed_size: 90981, storage_mode: 8, mtime: mtime)
      
      buf.rewind
      br = ByteReader.new(buf)
      br.read_4b # Signature
      br.read_2b # Version needed to extract
      expect(br.read_2b).to eq(2048)       # gp flags
    end
  end
end
