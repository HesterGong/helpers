# Foxden-Data Local Development Guide

## Problem
When working on `foxcom-forms-backend` (or other services that depend on `@foxden/data`), you may encounter TypeScript errors like:

```
TS2724: '"@foxden/data"' has no exported member named 'ApplicationGroupDocument'. 
Did you mean 'ApplicationDocument'?
```

This occurs when your local version of `foxden-data` has changes that haven't been published to npm yet, or when there's a mismatch between the installed package and the latest code.

## Solution: Build and Link Foxden-Data Locally

### Step 1: Build Foxden-Data
Navigate to the foxden-data repository and build it:

```bash
cd ~/Desktop/repos/foxden-data
yarn build
```

This will generate the `dist` folder with compiled TypeScript files.

### Step 2: Copy Dist to Node Modules
Copy the built `dist` folder into the consuming service's node_modules:

```bash
# For foxcom-forms-backend
cp -r ~/Desktop/repos/foxden-data/dist/* ~/Desktop/repos/foxcom-forms-backend/node_modules/@foxden/data/dist/

# For other services, adjust the path accordingly
# Example for foxden-admin-portal-backend:
# cp -r ~/Desktop/repos/foxden-data/dist/* ~/Desktop/repos/foxden-admin-portal-backend/node_modules/@foxden/data/dist/
```

### Step 3: Restart Your Service
Restart the development server:

```bash
cd ~/Desktop/repos/foxcom-forms-backend
yarn start
```

## When to Use This Approach

- **Local Development**: When you're making changes to `foxden-data` and need to test them immediately in another service
- **TypeScript Errors**: When you see import errors from `@foxden/data`
- **Version Mismatches**: When your code references types or exports that don't exist in the published package

## Alternative: Yarn Link (For Ongoing Development)

If you're actively developing `foxden-data` and need live updates, consider using yarn link:

```bash
# In foxden-data directory
cd ~/Desktop/repos/foxden-data
yarn link

# In the consuming service
cd ~/Desktop/repos/foxcom-forms-backend
yarn link @foxden/data
```

**Note**: Remember to rebuild foxden-data after each change when using yarn link.

## Troubleshooting

### Changes Not Reflecting
- Ensure you ran `yarn build` in foxden-data after making changes
- Clear the node_modules cache: `rm -rf node_modules/@foxden/data && yarn install`
- Restart your development server with a clean slate

### Still Seeing Errors
- Check that the export actually exists in foxden-data source code
- Verify the dist folder was copied correctly
- Check for typos in import statements

## Best Practices

1. **Always rebuild**: After modifying foxden-data, always run `yarn build` before copying
2. **Document changes**: Keep track of what changes you made to foxden-data that require this local linking
3. **Publish updates**: Once changes are stable, publish a new version of foxden-data to npm
4. **Update dependencies**: After publishing, update the version in package.json of consuming services

## Related Services

Services that commonly depend on `@foxden/data`:
- foxcom-forms-backend
- foxden-admin-portal-backend
- foxden-rating-quoting-backend
- foxden-policy-document-backend
- foxcom-payment-backend

---

**Last Updated**: February 25, 2026
