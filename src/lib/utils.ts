export const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

export const retryWithBackoff = async <T>(
  fn: () => Promise<T>,
  maxAttempts: number,
  baseDelay: number = 1000
): Promise<T> => {
  let attempt = 1;
  
  while (attempt <= maxAttempts) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === maxAttempts) throw error;
      
      const delay = baseDelay * Math.pow(2, attempt - 1);
      await sleep(delay);
      attempt++;
    }
  }
  
  throw new Error('Max retry attempts reached');
};

const formatPrice = (price: number): string => {
  return `${price.toFixed(2)} zł`;
};