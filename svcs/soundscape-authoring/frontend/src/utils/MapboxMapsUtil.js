// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

// More info: https://docs.microsoft.com/en-us/rest/api/maps/render-v2/get-map-tile

export const osmMapAttribution =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';

// export const osmMapsTilesetIDs = [
//   { name: 'Default', id: 'microsoft.base.road', default: true },
//   { name: 'Dark', id: 'microsoft.base.darkgrey' },
//   { name: 'Satellite', id: 'microsoft.imagery' },
// ];

// let defaultMapOptions = {
//   tilesetId: 'microsoft.base.road',
//   tileSize: '256',
//   language: 'en-US',
//   view: 'Auto',
// };

export const osmMapUrl = (tilesetId = '{s}') => {
  return `https://${tilesetId}.tile.openstreetmap.org/{z}/{x}/{y}.png`;
};
