//
//  ImageBrowserViewController.swift
//  HiPDA
//
//  Created by leizh007 on 2017/5/28.
//  Copyright © 2017年 HiPDA. All rights reserved.
//

import UIKit
import SDWebImage

class ImageBrowserViewController: BaseViewController {
    var imageURLs: [String]!
    var selectedIndex: Int!
    @IBOutlet fileprivate weak var collectionView: UICollectionView!
    @IBOutlet fileprivate weak var pageControl: UIPageControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.delegate = self
        collectionView.dataSource = self
        if #available(iOS 10.0, *) {
            collectionView.prefetchDataSource = self
        }
        pageControl.numberOfPages = imageURLs.count
        pageControl.currentPage = selectedIndex
        pageControl.isHidden = imageURLs.count == 1
        // https://stackoverflow.com/questions/14977896/xcode-collectionviewcontroller-scrolltoitematindexpath-not-working
        view.layoutIfNeeded()
        collectionView.scrollToItem(at: IndexPath(row: selectedIndex, section: 0), at: .centeredHorizontally, animated: false)
    }
        
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

// MARK: - UICollectionViewDelegate

extension ImageBrowserViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? ImageBrowserCollectionViewCell)?.resetState()
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? ImageBrowserCollectionViewCell)?.resetState()
    }
    
    // MARK: - UIScrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        pageControl.currentPage = Int(floor(scrollView.contentOffset.x / scrollView.frame.size.width + 0.5))
    }
}

// MARK: - UICollectionViewDataSource

extension ImageBrowserViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageURLs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageBrowserCollectionViewCell.reuseIdentifier, for: indexPath) as? ImageBrowserCollectionViewCell else {
            fatalError()
        }
        cell.imageURLString = imageURLs[indexPath.row]
        cell.delegate = self
        
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension ImageBrowserViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return UIScreen.main.bounds.size
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension ImageBrowserViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = imageURLs.filter { $0.contains(".thumb.jpg") }.map { $0.replacingOccurrences(of: ".thumb.jpg", with: "") }.flatMap { URL(string: $0) }
        SDWebImagePrefetcher.shared().prefetchURLs(urls)
    }
}

// MARK: - ImageBrowserCollectionViewCellDelegate

extension ImageBrowserViewController: ImageBrowserCollectionViewCellDelegate {
    func pressed(cell: ImageBrowserCollectionViewCell) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    func longPressedCell(_ cell: ImageBrowserCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell), var url = imageURLs.safe[indexPath.row] else { return }
        url = url.replacingOccurrences(of: ".thumb.jpg", with: "")
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let copy = UIAlertAction(title: "复制", style: .default) { [weak self] _ in
            guard let `self` = self else { return }
            URLDispatchManager.shared.shouldHandlePasteBoardChanged = false
            self.showPromptInformation(of: .loading("正在复制..."))
            ImageUtils.copyImage(url: url) { [weak self] (result) in
                self?.hidePromptInformation()
                switch result {
                case let .failure(error):
                    self?.showPromptInformation(of: .failure(error.localizedDescription))
                case .success(_):
                    self?.showPromptInformation(of: .success("复制成功！"))
                }
            }
        }
        let save = UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let `self` = self else { return }
            self.showPromptInformation(of: .loading("正在保存..."))
            ImageUtils.saveImage(url: url) { [weak self] (result) in
                self?.hidePromptInformation()
                switch result {
                case let .failure(error):
                    self?.showPromptInformation(of: .failure(error.localizedDescription))
                case .success(_):
                    self?.showPromptInformation(of: .success("保存成功！"))
                }
            }
        }
        let detectQrCode = UIAlertAction(title: "识别图中二维码", style: .default) { [weak self] _ in
            guard let `self` = self else { return }
            self.showPromptInformation(of: .loading("正在识别..."))
            ImageUtils.qrcode(from: url) { [weak self] result in
                self?.hidePromptInformation()
                switch result {
                case let .success(qrCode):
                    self?.showQrCode(qrCode)
                case let .failure(error):
                    self?.showPromptInformation(of: .failure(error.localizedDescription))
                }
            }
        }
        let cancel = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        actionSheet.addAction(copy)
        actionSheet.addAction(save)
        actionSheet.addAction(detectQrCode)
        actionSheet.addAction(cancel)
        present(actionSheet, animated: true, completion: nil)
    }
    
    fileprivate func showQrCode(_ qrCode: String) {
        let actionSheet = UIAlertController(title: "识别二维码", message: "二维码内容为: \(qrCode)", preferredStyle: .actionSheet)
        let copy = UIAlertAction(title: "复制", style: .default) { _ in
            URLDispatchManager.shared.shouldHandlePasteBoardChanged = false
            UIPasteboard.general.string = qrCode
        }
        var openLink: UIAlertAction!
        if qrCode.isLink {
            openLink = UIAlertAction(title: "打开链接", style: .default, handler: { _ in
                URLDispatchManager.shared.linkActived(qrCode)
            })
        }
        let cancel = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        actionSheet.addAction(copy)
        if qrCode.isLink {
            actionSheet.addAction(openLink)
        }
        actionSheet.addAction(cancel)
        present(actionSheet, animated: true, completion: nil)
    }
}

// MARK: - StoryboardLoadable

extension ImageBrowserViewController: StoryboardLoadable {}
