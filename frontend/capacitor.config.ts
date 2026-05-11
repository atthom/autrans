import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.autrans.app',
  appName: 'Autrans',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
  }
};

export default config;