import { defineConfig } from 'vitepress';
import { withMermaid } from 'vitepress-plugin-mermaid';
import fs from 'node:fs';
import path from 'node:path';

export default withMermaid(
  defineConfig({
    mermaid: {
      startOnLoad: false
    },
    mermaidPlugin: {
      class: 'mermaid-diagram'
    },
    title: 'Node.aec Developer API',
    description: 'Programmatic BIM product, version, release binary, and curation management for the Node.aec ecosystem.',
    base: '/developer-api/',
    rewrites: {
      'README.md': 'index.md'
    },
    cleanUrls: false,
    buildEnd: async ({ outDir }) => {
      const src = path.resolve(outDir, '../../examples');
      const dest = path.resolve(outDir, 'examples');
      if (fs.existsSync(src)) {
        fs.cpSync(src, dest, { recursive: true });
      }
    },
    themeConfig: {
      siteTitle: 'Node.aec Developer API',
      nav: [
        { text: 'Overview', link: '/' },
        { text: 'Authentication', link: '/authentication' },
        { text: 'CI/CD Examples', link: '/ci-cd-examples' },
        { text: 'Node.aec Platform', link: 'https://nodeaec.com.br' }
      ],
      sidebar: [
        {
          text: 'Developer API Reference',
          items: [
            { text: 'Overview & Quickstart', link: '/' },
            { text: 'Authentication & Security', link: '/authentication' },
            { text: 'Products & Media', link: '/products-and-media' },
            { text: 'Versions & Release Binaries', link: '/versions-and-releases' },
            { text: 'Submissions & Manifests', link: '/submissions-and-manifests' },
            { text: 'CI/CD Pipeline Examples', link: '/ci-cd-examples' }
          ]
        }
      ],
      search: {
        provider: 'local'
      },
      socialLinks: [
        { icon: 'github', link: 'https://github.com/nodeaec/developer-api' }
      ],
      footer: {
        message: 'Node.aec Developer Ecosystem',
        copyright: 'Copyright © 2026 Node.aec'
      }
    }
  })
);
