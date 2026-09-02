<template>
  <svg
    viewBox="0 0 512 512"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    :class="className"
  >
    <!-- Background Squircle -->
    <rect
      v-if="withBackground"
      width="512"
      height="512"
      rx="115"
      ry="115"
      fill="#F4F1E6"
    />

    <!-- Top Row Sumi Dark Tiles -->
    <rect x="109" y="109" width="88" height="88" rx="22" ry="22" :fill="darkTileColor" />
    <rect x="212" y="109" width="88" height="88" rx="22" ry="22" :fill="darkTileColor" />
    <rect x="315" y="109" width="88" height="88" rx="22" ry="22" :fill="darkTileColor" />

    <!-- Middle Row Matcha Accent Tile -->
    <rect x="212" y="212" width="88" height="88" rx="22" ry="22" fill="#7F9F3C" />

    <!-- Bottom Row Sumi Dark Tile -->
    <rect x="212" y="315" width="88" height="88" rx="22" ry="22" :fill="darkTileColor" />
  </svg>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    className?: string;
    withBackground?: boolean;
    darkTileColor?: string;
  }>(),
  {
    className: 'w-8 h-8',
    withBackground: true,
    darkTileColor: '#1D2B21',
  }
);
</script>
