import sys

if len(sys.argv) < 2:
    print("Please provide a binary file path as a command line argument.")
    sys.exit()

input_file_path = sys.argv[1]
output_file_path = input_file_path + ".hex"

with open(input_file_path, "rb") as input_file:
    with open(output_file_path, "w") as output_file:
        while True:
            byte = input_file.read(1)
            if not byte:
                break
            output_file.write("{:02x}\n".format(ord(byte)))
