import { BlobServiceClient } from "@azure/storage-blob";
import { DefaultAzureCredential } from "@azure/identity";

// Receipt images live in a PRIVATE blob container (allowBlobPublicAccess=false,
// shared-key access disabled). Access is identity-based: the Function's managed
// identity has "Storage Blob Data Owner", so we upload/download with a token —
// never an account key, and never a public URL. Receipts are served back only
// through the authenticated GET /expenses/{id}/receipt proxy.

const account =
  process.env.RECEIPTS_STORAGE_ACCOUNT ?? process.env.AzureWebJobsStorage__accountName;
const container = process.env.RECEIPTS_CONTAINER ?? "receipts";

let serviceClient: BlobServiceClient | null = null;

function service(): BlobServiceClient {
  if (!account) {
    throw new Error("RECEIPTS_STORAGE_ACCOUNT (storage account name) is not configured.");
  }
  if (!serviceClient) {
    serviceClient = new BlobServiceClient(
      `https://${account}.blob.core.windows.net`,
      new DefaultAzureCredential()
    );
  }
  return serviceClient;
}

/** Upload a receipt image and return its (private) blob URL. */
export async function uploadReceipt(
  blobName: string,
  data: Buffer,
  contentType: string
): Promise<string> {
  const blob = service().getContainerClient(container).getBlockBlobClient(blobName);
  await blob.uploadData(data, { blobHTTPHeaders: { blobContentType: contentType } });
  return blob.url;
}

/** Download a receipt by its blob name (path within the container). */
export async function downloadReceipt(
  blobName: string
): Promise<{ data: Buffer; contentType: string }> {
  const blob = service().getContainerClient(container).getBlockBlobClient(blobName);
  const data = await blob.downloadToBuffer();
  const props = await blob.getProperties();
  return { data, contentType: props.contentType ?? "application/octet-stream" };
}

/** Extract the blob name (path within the container) from a stored blob URL. */
export function blobNameFromUrl(url: string): string | null {
  try {
    const path = new URL(url).pathname.replace(/^\/+/, ""); // "receipts/<name>"
    const prefix = `${container}/`;
    return path.startsWith(prefix) ? decodeURIComponent(path.slice(prefix.length)) : null;
  } catch {
    return null;
  }
}
