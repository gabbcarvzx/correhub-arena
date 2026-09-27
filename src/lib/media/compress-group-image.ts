export async function compressGroupImage(file: File, kind: "avatar" | "cover"): Promise<File> {
  if (file.size > 8_000_000) throw new Error("Escolha uma imagem de até 8 MB.");
  const bitmap = await createImageBitmap(file);
  try {
    if (bitmap.width * bitmap.height > 24_000_000) throw new Error("Escolha uma imagem com até 24 megapixels.");
    const side = kind === "avatar" ? 512 : 1600;
    const scale = Math.min(1, side / Math.max(bitmap.width, bitmap.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(bitmap.width * scale));
    canvas.height = Math.max(1, Math.round(bitmap.height * scale));
    canvas.getContext("2d", { alpha: false })?.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/webp", 0.82));
    if (!blob) throw new Error("Não foi possível preparar a imagem.");
    const limit = kind === "avatar" ? 250_000 : 600_000;
    if (blob.size > limit) throw new Error("A imagem continua grande. Escolha uma imagem menor.");
    return new File([blob], `${kind}.webp`, { type: "image/webp" });
  } finally {
    bitmap.close();
  }
}
