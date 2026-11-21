export function averageRating(reviews) {
  const sum = reviews.reduce((acc, review) => acc + review.stars, 0);
  return Math.round((sum / reviews.length) * 10) / 10;
}
