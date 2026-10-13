# frozen_string_literal: true

require 'openssl'
require 'securerandom'

module Cistergraphia
  # Secret mode: real encryption behind the Cistercian glyphs.
  #
  # The message (any UTF-8 text) is encrypted with AES-256-GCM under a key
  # derived from a passphrase with scrypt. The resulting bytes are written as
  # base-10000 digits, one glyph each, so the picture looks like the game mode
  # but carries no structure: no tablet, no pairs, no evil marker. Without the
  # passphrase only the approximate message length can be learned, and GCM
  # rejects any tampered glyph.
  #
  # Payload layout (before base-10000 encoding):
  #   version (1 byte) | salt (16) | nonce (12) | ciphertext | GCM tag (16)
  # The version byte selects the KDF and cipher parameters, so they can be
  # strengthened later while old images stay decodable. It is authenticated as
  # associated data.
  #
  # Glyph sequence layout:
  #   [length / 10000, length % 10000, *payload digits, *random padding]
  # Padding glyphs are uniformly random, like the payload, and fill the square.
  module Secret
    VERSION = 1
    # OWASP-listed equivalent of N=2^17, r=8, p=1 that needs 16 MiB instead of 128 MiB
    SCRYPT = { N: 2**14, r: 8, p: 5 }.freeze
    CIPHER = 'aes-256-gcm'
    SALT_BYTES = 16
    NONCE_BYTES = 12
    TAG_BYTES = 16
    HEADER_BYTES = 1 + SALT_BYTES + NONCE_BYTES
    MIN_PASSPHRASE_LENGTH = 8
    BASE = 10_000

    module_function

    # Message + passphrase => sequence of numbers (0..9999) padded to a perfect square
    def encrypt(message, passphrase)
      plaintext = message.to_s.strip
      raise EmptyMessageError, 'Message is empty' if plaintext.empty?

      pad_to_square(frame(to_digits(seal(plaintext, passphrase))))
    end

    # Inverse of #encrypt; raises DecodeError on a wrong passphrase or any tampering
    def decrypt(sequence, passphrase)
      raise DecodeError, 'Too few symbols for a secret message' if sequence.size < 2

      length = (sequence[0] * BASE) + sequence[1]
      digits = sequence[2, length]
      raise DecodeError, 'Secret message is truncated' if digits.nil? || digits.size != length

      unseal(from_digits(digits), passphrase)
    end

    # Two length glyphs, then the payload glyphs
    def frame(digits)
      [digits.size / BASE, digits.size % BASE, *digits]
    end

    # Random glyphs, indistinguishable from the ciphertext, fill the square grid
    def pad_to_square(sequence)
      size = Integer.sqrt(sequence.size)
      size += 1 unless size**2 == sequence.size
      sequence + Array.new((size**2) - sequence.size) { SecureRandom.random_number(BASE) }
    end

    def seal(plaintext, passphrase)
      header = [VERSION].pack('C') + SecureRandom.random_bytes(SALT_BYTES) + SecureRandom.random_bytes(NONCE_BYTES)
      cipher = aead(:encrypt, passphrase, header)
      header + cipher.update(plaintext.encode(Encoding::UTF_8)) + cipher.final + cipher.auth_tag(TAG_BYTES)
    end

    def unseal(payload, passphrase)
      header, body, tag = split_payload(payload)
      decipher = aead(:decrypt, passphrase, header)
      decipher.auth_tag = tag
      (decipher.update(body) + decipher.final).force_encoding(Encoding::UTF_8)
    rescue OpenSSL::Cipher::CipherError
      raise DecodeError, 'Wrong passphrase, or the image was not made in secret mode or was altered'
    end

    def split_payload(payload)
      raise DecodeError, 'Secret message is too short' if payload.bytesize < HEADER_BYTES + TAG_BYTES

      version = payload.getbyte(0)
      raise DecodeError, "Unsupported secret format version #{version}" unless version == VERSION

      [payload.byteslice(0, HEADER_BYTES), payload.byteslice(HEADER_BYTES...-TAG_BYTES),
       payload.byteslice(-TAG_BYTES, TAG_BYTES)]
    end

    # AES-256-GCM context keyed from the passphrase and the salt in the header,
    # with the whole header (version, salt, nonce) authenticated
    def aead(direction, passphrase, header)
      cipher = OpenSSL::Cipher.new(CIPHER).public_send(direction)
      cipher.key = key(passphrase, header.byteslice(1, SALT_BYTES))
      cipher.iv = header.byteslice(1 + SALT_BYTES, NONCE_BYTES)
      cipher.auth_data = header
      cipher
    end

    def key(passphrase, salt)
      passphrase = passphrase.to_s
      if passphrase.length < MIN_PASSPHRASE_LENGTH
        raise Error, "Passphrase must be at least #{MIN_PASSPHRASE_LENGTH} characters"
      end

      OpenSSL::KDF.scrypt(passphrase.encode(Encoding::UTF_8), salt: salt, length: 32, **SCRYPT)
    end

    # Bytes => base-10000 digits. A leading 0x01 byte keeps leading zero bytes.
    def to_digits(bytes)
      ("\x01".b + bytes.b).unpack1('H*').to_i(16).digits(BASE).reverse
    end

    def from_digits(digits)
      raise DecodeError, 'Invalid secret symbol' unless digits.all? { |d| d.between?(0, BASE - 1) }

      bytes = integer_to_bytes(digits.inject(0) { |acc, d| (acc * BASE) + d })
      raise DecodeError, 'Corrupted secret message' unless bytes.getbyte(0) == 1

      bytes.byteslice(1..)
    end

    def integer_to_bytes(int)
      hex = int.to_s(16)
      [hex.size.odd? ? "0#{hex}" : hex].pack('H*')
    end
  end
end
