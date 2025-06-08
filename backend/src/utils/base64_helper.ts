import fs from "fs/promises";
/**
 * Helper functions to convert files to and from base64 strings
 */
const base64Helper = {
  toBase64: async (filePath: string): Promise<string> => {
    try {
      const fileBuffer = await fs.readFile(filePath);
      return fileBuffer.toString("base64");
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`Error converting file to base64: ${error.message}`);
      } else {
        throw new Error("Error converting file to base64");
      }
    }
  },
  fromBase64: async (
    base64String: string,
    outputFilePath: string
  ): Promise<void> => {
    try {
      const fileBuffer = Buffer.from(base64String, "base64");
      await fs.writeFile(outputFilePath, fileBuffer);
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`Error converting base64 to file: ${error.message}`);
      } else {
        throw new Error("Error converting base64 to file");
      }
    }
  },
};

export default base64Helper;
