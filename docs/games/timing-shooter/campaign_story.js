class CampaignStory {
  constructor(stage, transition) {
    this.transition = transition;
    this.layer = document.createElement('section');
    this.layer.className = 'campaign-story';
    this.layer.hidden = true;
    this.layer.innerHTML = '<img alt=""><div class="campaign-story-dialogue"><h2></h2><p></p><button type="button">탭하여 계속</button></div>';
    stage.append(this.layer);
    this.button = this.layer.querySelector('button');
    this.button.onclick = () => this.resolve?.(true);
  }

  prepare(pages) {
    return Promise.all(pages.map(page => {
      const image = new Image();
      image.src = page.image;
      return image.decode();
    }));
  }

  async play(pages) {
    this.cancel();
    const token = this.token;
    for (let index = 0; index < pages.length; index++) {
      const page = pages[index];
      this.button.disabled = true;
      const nextImage = new Image();
      nextImage.src = page.image;
      await nextImage.decode();
      if (token !== this.token) return false;
      await this.transition(() => {
        if (token !== this.token) return;
        const image = this.layer.querySelector('img');
        image.src = page.image;
        image.alt = page.title;
        this.layer.querySelector('h2').textContent = page.title;
        this.layer.querySelector('p').textContent = page.text;
        this.layer.classList.toggle('story-emphasis', Boolean(page.emphasis));
        this.button.textContent = page.next ?? '탭하여 계속';
        this.layer.dataset.page = String(index);
        this.layer.hidden = false;
      });
      if (token !== this.token) return false;
      const next = new Promise(resolve => { this.resolve = resolve; });
      this.button.disabled = false;
      this.button.focus({ preventScroll: true });
      if (!await next || token !== this.token) return false;
      this.resolve = null;
    }
    this.button.disabled = true;
    return true;
  }

  cancel() {
    this.token = (this.token ?? 0) + 1;
    this.resolve?.(false);
    this.resolve = null;
    this.layer.hidden = true;
  }
}
window.CampaignStory = CampaignStory;
